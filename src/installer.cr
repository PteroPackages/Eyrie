require "semantic_compare"
require "semantic_version"
require "./package"
require "./resolvers/*"

module Eyrie
  class Installer
    def initialize(lock)
      @lock = !lock
    end

    def run(modules : Array(ModuleSpec)) : Nil
      check_prerequisites

      validated = [] of ModuleSpec
      modules.each { |s| validated << validate_spec s }

      s = validated.size
      validated.each_with_index do |spec, i|
        next unless install spec
        if process spec
          Log.info { "[#{i+1}/#{s}] installed: #{spec.name}" }
        else
          next
        end
      end
    end

    private def check_prerequisites : Nil
      Log.vinfo { "checking panel availability" }
      unless Dir.exists? "/var/www/pterodactyl"
        Log.fatal { "panel root directory not found (path: /var/www/pterodactyl)" }
      end

      Log.vinfo { "checking cache availability" }
      unless Dir.exists? "/var/eyrie/cache"
        Log.vinfo { "cache directory not found; attempting to create" }
        begin
          Dir.mkdir_p "/var/eyrie/cache"
        rescue ex
          Log.fatal(ex) { "failed to create cache directory" }
        end
      end

      unless Dir.empty? "/var/eyrie/cache"
        Log.vinfo { "cache directory not empty; attempting clean" }
        Dir.glob("/var/eyrie/cache")[1..].each do |path|
          begin
            File.delete path
          rescue
            Log.vwarn { "failed to remove cached path:" }
            Log.vwarn { path }
          end
        end
      end

      Log.vinfo { "checking git availability" }
      begin
        `git --version`
      rescue ex
        Log.fatal(ex) { "git is required for this operation" }
      end

      Log.vinfo { "prerequisite checks completed" }
    end

    private def validate_spec(spec : ModuleSpec) : ModuleSpec
      Log.vinfo { "validating module: #{spec.name}" }
      Log.error { "missing name for module" } if spec.name.empty?

      if spec.name =~ %r[[^a-z0-9_-]]
        Log.error { "invalid module name format '#{spec.name}'" }
        Log.fatal { "name can contain: lowercase letters, numbers, dashes, and underscores" }
      end

      unless spec.version == "*"
        begin
          SemanticVersion.parse spec.version
        rescue ex
          Log.fatal(ex) { "invalid module version format for module '#{spec.name}'" }
        end
      end

      {% for src in %w(github gitlab) %}
        if spec.source.type.{{ src.id }}? && !spec.source.url.starts_with?("https://{{ src.id }}.com")
        spec.source.url = "https://{{ src.id }}.com/#{spec.source.url}"
        end
      {% end %}

      spec
    end

    private def validate_mod(mod : Module) : Bool
      if mod.name =~ %r[[^a-z0-9_-]]
        Log.error { "invalid module name format '#{mod.name}'" }
        Log.error { "name can contain: lowercase letters, numbers, dashes, and underscores" }
        return false
      end

      begin
        SemanticVersion.parse mod.version
      rescue ex
        Log.error(ex) { "failed to parse module version" }
        return false
      end

      if mod.authors.empty?
        Log.warn { "no authors set for package" }
      else
        mod.authors.each do |author|
          Log.warn { "missing name for author" } if author.name.empty?
          Log.warn { "missing contact for author" } if author.contact.empty?
        end
      end

      if mod.supports.empty?
        Log.error { "no supported panel versions specified; cannot install module" }
        return false
      end

      if mod.files.include.empty?
        Log.error { "no include paths specified; cannot assume files to process" }
        return false
      end

      true
    end

    private def install(spec : ModuleSpec) : Bool
      Log.info { "installing: #{spec.name}" }
      res = false

      if spec.source.type.local?
        res = LocalResolver.run spec
      else
        res = GitResolver.run spec
      end

      if res
        Log.info { "module #{spec.name}: installed" }
      else
        Log.info { "module #{spec.name}: failed" }
      end

      res
    end

    private def require_mod(spec : ModuleSpec) : Module?
      path = Resolver.cache_path / spec.name / "eyrie.modules.yml"
      unless File.exists? path
        Log.error { "modules file not found for '#{spec.name}'" }
        return
      end

      mod = uninitialized Module
      begin
        data = File.read path
        mod = Module.from_yaml data
      rescue ex : YAML::ParseException
        Log.error(ex) { "failed to parse modules file" }
      rescue ex
        Log.error(ex) { }
      end

      mod
    end

    private def exec(dir : String, command : String) : Exception?
      begin
        Process.exec command, shell: true, chdir: dir
      rescue ex
        ex
      end
    end

    private def process(spec : ModuleSpec) : Bool
      mod = require_mod spec
      return false unless mod
      root = "/var/www/pterodactyl"

      unless File.exists? "#{root}/config/app.php"
        Log.error { "panel 'app.php' config file not found; cannot continue" }
        return false
      end

      info = File.read "#{root}/config/app.php"
      info =~ /'version' \=\> '(.*)'/
      unless $1?
        Log.error { "could not get panel version from config" }
        return false
      end

      valid : String? = nil
      if mod.supports.any? { |v| v.match %r[[*~<>=^]+] }
        parsed = SemanticVersion.try &.parse $1
        unless parsed
          Log.error { "failed to parse panel version" }
          return false
        end

        valid = mod.supports.find { |v| SemanticCompare.simple_expression parsed, v }
      else
        valid = mod.supports.find { |v| v == $1 }
      end

      unless valid
        Log.error { "this module does not support panel version #{$1}" }
        return false
      end

      loc = Resolver.cache_path / spec.name
      Dir.cd(loc) do
        includes = Dir.glob mod.files.include
        excludes = Dir.glob mod.files.exclude

        includes.reject! { |f| f.in? excludes }

        includes.each do |path|
          if File.exists? (dest = File.join(root, path))
            Log.vinfo { "attempting to remove existing resource path:" }
            Log.vinfo { dest }
            begin
              File.delete dest
            rescue
              Log.vwarn { "failed to remove file; attempting overwrite" }
              data = File.read loc / path
              begin
                File.write dest, data
              rescue ex
                Log.error(ex) { "failed to overwrite resource path" }
                next
              end
            end
          end

          begin
            File.copy path, File.join(loc / path)
          rescue ex
            Log.error(ex) { "failed to move resource path:" }
            Log.error { path }
          end
        end
      end

      true
    end
  end
end

require "semantic_version"
require "./package"
require "./resolvers/*"

module Eyrie
  class Installer
    def initialize(lock)
      @lock = !lock
    end

    def run(modules : Array(ModuleSpec)) : Nil
      require_git
      require_cache
      require_panel_path

      validated = [] of ModuleSpec
      modules.each { |s| validated << validate_spec s }
      Log.info { "installing packages" }

      s = validated.size
      validated.each do |spec|
        next unless install(spec)
        if mod = require_mod(spec)
          process(mod)
        end
      end
    end

    private def require_git : Nil
      begin
        Process.run "git --version", shell: true
      rescue
        Log.fatal { "git is required for this operation" }
      end
    end

    private def require_cache : Nil
      Log.vinfo { "ensuring cache availability" }
      path = Resolver.cache_path

      unless File.exists?(path) && File.directory?(path)
        Log.warn { "cache directory not found, attempting to create" }
        begin
          Dir.mkdir_p path
        rescue ex
          Log.fatal(ex) { }
        end
      end

      unless Dir.empty? path
        begin
          Dir.entries(path).each { |e| File.delete e }
        rescue
          Log.warn { "failed to clear old files from cache" }
        end
      end
    end

    private def require_panel_path : Nil
      Log.vinfo { "checking panel path availability" }

      unless Dir.exists? "/var/www/pterodactyl"
        Log.fatal { "panel root path not found (path: /var/www/pterodactyl)" }
      end
    end

    private def validate_spec(spec : ModuleSpec) : ModuleSpec
      Log.vinfo { "validating module: #{spec.name}" }
      Log.error { "missing name for module" } if spec.name.empty?

      if spec.name =~ %r[[^a-zA-Z0-9_-]]
        Log.error { "invalid module name format '#{spec.name}'" }
        Log.fatal { "name can contain: letters, numbers, dashes, and underscores" }
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
      if mod.name =~ %r[[^a-zA-Z0-9_-]]
        Log.error { "invalid module name format '#{mod.name}'" }
        Log.fatal { "name can contain: letters, numbers, dashes, and underscores" }
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

    private def process(mod : Module) : Nil
    end
  end
end

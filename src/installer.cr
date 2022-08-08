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
      modules.each { |m| validated << validate_spec m }
      Log.info { "installing packages" }

      s = validated.size
      validated.each do |mod|
        next unless install(mod)
        if cfg = require_mod(mod)
          process(cfg)
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

      root = Path["var"] / "www" / "pterodactyl"
      unless File.exists? root
        Log.error { "panel root path not found" }
        Log.fatal { "default location is #{root}; ensure path is available" }
      end
    end

    private def validate_spec(mod : ModuleSpec) : ModuleSpec
      Log.vinfo { "validating module: #{mod.name}" }
      Log.error { "missing name for module" } if mod.name.empty?

      if mod.name =~ %r[[^a-zA-Z0-9_-]]
        Log.error { "invalid module name format '#{mod.name}'" }
        Log.fatal { "name can contain: letters, numbers, dashes, and underscores" }
      end

      unless mod.version == "*"
        begin
          SemanticVersion.parse mod.version
        rescue ex
          Log.fatal(ex) { "invalid module version format for module '#{mod.name}'" }
        end
      end

      {% for src in %w(github gitlab) %}
        if mod.source.type.{{ src.id }}? && !mod.source.url.starts_with?("https://{{ src.id }}.com")
          mod.source.url = "https://{{ src.id }}.com/#{mod.source.url}"
        end
      {% end %}

      mod
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

    private def install(mod : ModuleSpec) : Bool
      Log.info { "installing: #{mod.name}" }
      res = false

      if mod.source.type.local?
        res = LocalResolver.run mod
      else
        res = GitResolver.run mod
      end

      if res
        Log.info { "module #{mod.name}: installed" }
      else
        Log.info { "module #{mod.name}: failed" }
      end

      res
    end

    private def require_mod(mod : ModuleSpec) : Module?
      path = Resolver.cache_path / mod.name / "eyrie.modules.yml"
      unless File.exists? path
        Log.error { "modules file not found for '#{mod.name}'" }
        return
      end

      cfg = uninitialized Module
      begin
        data = File.read path
        cfg = Module.from_yaml data
      rescue ex : YAML::ParseException
        Log.error(ex) { "failed to parse modules file" }
      rescue ex
        Log.error(ex) { }
      end

      cfg
    end

    private def process(cfg : Module) : Nil
    end
  end
end

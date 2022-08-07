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

      validated = [] of ModuleSpec
      modules.each { |m| validated << validate m }
      Log.vinfo { "installing packages" }

      status = [] of Bool
      validated.each { |m| status << install m }
      done = status.select(&.dup).size

      Log.info { "installed #{done} of #{status.size} modules" }
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

    private def validate(mod : ModuleSpec) : ModuleSpec
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

      if mod.source.type.github? && !mod.source.url.starts_with?("https://github.com")
        mod.source.url = "https://github.com/#{mod.source.url}"
        puts mod.source.url
      end

      mod
    end

    private def install(mod : ModuleSpec) : Bool
      res = false

      case mod.source.type
      in SourceType::Local  then res = LocalResolver.run mod
      in SourceType::Git    then res = GitResolver.run mod
      in SourceType::Github then res = GithubResolver.run mod
      end

      res
    end
  end
end

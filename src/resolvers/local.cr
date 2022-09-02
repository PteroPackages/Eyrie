require "./git"
require "./resolver"

module Eyrie
  class LocalResolver < Resolver
    def self.run(spec : ModuleSpec) : Bool
      mod = Module.from_path spec.source.uri
      mod.validate
      run mod
    rescue ex
      Log.fatal ex
    end

    def self.run(mod : Module) : Bool
      unless src = mod.source
        Log.error "no source set for module '#{mod.name}', cannot install"
        return false
      end

      return GitResolver.run mod.to_spec unless src.type.local?

      path = if src.uri.starts_with? '.'
               File.expand_path File.join(Dir.current, src.uri)
             else
               File.expand_path src.uri
             end

      unless File.exists? path
        Log.error "source files for module '#{mod.name}' not found"
        return false
      end

      cache = File.join "/var/eyrie/cache", mod.name
      begin
        FileUtils.cp path, cache
      rescue ex
        Log.error ex, "failed to move module files to cache"
        return false
      end

      true
    rescue ex
      Log.error ex, "failed to resolve module '#{mod.name}':"
      false
    end
  end
end

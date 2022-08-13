require "./git"
require "./resolver"

module Eyrie
  class LocalResolver < Resolver
    def self.run(spec : ModuleSpec) : Bool
      mod = Module.from_path spec.source.url
      mod.validate

      unless src = mod.source
        Log.error "no source set for module '#{mod.name}', cannot install"
        return false
      end

      return GitResolver.run mod.to_spec unless src.type.local?

      path = if src.url.starts_with? '.'
               File.expand_path File.join(Dir.current, src.url)
             else
               File.expand_path src.url
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
    end
  end
end

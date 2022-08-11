require "./git"
require "./resolver"

module Eyrie
  class LocalResolver < Resolver
    def self.run(spec : ModuleSpec) : Bool
      mod = Module.from_path spec.source.url
      unless src = mod.source
        Log.error "no source set for module '#{mod.name}', cannot install"
        return false
      end

      path = if src.url.starts_with? '.'
        File.expand_path File.join(Dir.current, src.url)
      else
        File.expand_path src.url
      end

      Log.fatal "source files for module '#{mod.name}' not found" unless File.exists? path

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

require "./resolver"

module Eyrie
  class LocalResolver < Resolver
    def self.run(spec : ModuleSpec) : Bool
      src = Path[spec.source.url]
      unless File.exists? src
        Log.error { "invalid file path for module '#{spec.name}'" }
        return false
      end

      mod = uninitialized Module
      begin
        data = File.read src
        mod = ModuleSpec.from_yaml data
      rescue ex
        Log.error(ex) { "failed to read module file" }
        return false
      end

      begin
        mod.validate
      rescue ex
        Log.error(ex) { }
      end

      true
    end
  end
end

module Eyrie::Upgrader
  def self.run(specs : Array(ModuleSpec), root : String, ver : SemanticVersion) : Nil
    specs.each do |spec|
      run spec, root, ver
    end
  end

  def self.run(spec : ModuleSpec, root : String, ver : SemanticVersion) : Nil
    begin
      if spec.source.type.local?
        Resolver.pull_from_local spec.name, spec.source.uri
      else
        Resolver.pull_from_git spec.name, spec.source.uri
      end

      path = File.join "/var/eyrie/cache", spec.name, "eyrie.yml"
      Log.fatal "No eyrie.yml file found for #{spec.source.type.to_s.downcase} module" unless File.exists? path

      mod = Module.from_path path
    rescue ex : Error
      Log.fatal ex.format
    end

    begin
      mod.validate ver
    rescue ex : Error
      if ex.status.cannot_support?
        Log.fatal ex.format + ["Current version #{ver} does not satisfy requirement #{mod.supports}"]
      else
        Log.fatal ex.format
      end
    end

    return Log.info "No new version for module '#{mod.name}'" unless spec.version.accepts? mod.version

    Installer.install root, mod, mod.version
  end
end

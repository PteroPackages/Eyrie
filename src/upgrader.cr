module Eyrie
  class Upgrader
    def self.run(specs : Array(ModuleSpec), no_lock : Bool) : Nil
      Util.run_prerequisites
      Log.fatal "no modules have been installed or saved" if specs.empty?

      start = Time.monotonic
      specs.each do |spec|
        Log.vinfo "validating module spec '#{spec.name}'"
        spec.validate
      rescue ex
        Log.error "failed to validate module spec '#{spec.name}'"
        Log.fatal ex
      end

      modules = [] of {String, Module}
      specs.each do |spec|
        if mod = Installer.install spec
          version = SemanticVersion.parse mod.version
          if SemanticCompare.simple_expression version, ">" + spec.version
            modules << {spec.version, mod}
          else
            Log.info "no new version detected for module '#{spec.name}'"
          end
        end
      end

      Log.fatal "no modules could be resolved" if modules.empty?
      Log.info "upgrading #{modules.size} module#{"s" if modules.size != 1}"

      proc = Processor.new "/var/www/pterodactyl"
      done = [] of Module

      modules.each do |(v, mod)|
        Log.info "module '#{mod.name}': #{v.colorize(:yellow)} -> #{mod.version.colorize(:green)}"

        if proc.run mod
          if spec = specs.find { |s| s.name == mod.name }
            mod.source = spec.source if spec.source.type.local?
          end
          done << mod
        end
      end

      Log.fatal "no modules were installed" if done.empty?
      Installer.write_lockfile(done) unless no_lock

      taken = Time.monotonic - start
      Log.info "Upgraded #{done.size} module#{"s" if done.size != 1} in #{taken.milliseconds}ms"
    end
  end
end

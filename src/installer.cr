require "file_utils"
require "./resolvers/*"

module Eyrie::Installer
  def self.run(specs : Array(ModuleSpec), no_lock : Bool) : Nil
    Util.run_prerequisites
    proc = Processor.new "/var/www/pterodactyl"

    start = Time.monotonic
    specs.each do |spec|
      Log.vinfo "validating module spec '#{spec.name}'"
      spec.validate
    rescue ex
      Log.error "failed to validate module spec '#{spec.name}'"
      Log.fatal ex
    end

    modules = [] of Module
    specs.each do |spec|
      if mod = install spec
        modules << mod
      end
    end

    Log.fatal "no modules could be resolved" if modules.empty?
    Log.info "installing #{modules.size} module#{"s" if modules.size != 1}"

    done = [] of Module
    modules.each do |mod|
      if proc.run mod
        if spec = specs.find { |s| s.name == mod.name }
          mod.source = spec.source if spec.source.type.local?
        end
        done << mod
      end
    end

    Log.fatal "no modules were installed" if done.empty?
    write_lockfile(done) unless no_lock

    taken = Time.monotonic - start
    Log.info "installed #{done.size} module#{"s" if done.size != 1} in #{taken.milliseconds}ms"
  end

  def self.install(spec : ModuleSpec) : Module?
    res = if spec.source.type.local?
            LocalResolver.run spec
          else
            GitResolver.run spec
          end
    return unless res

    path = if spec.source.type.local?
             File.expand_path File.join(Dir.current, spec.source.url)
           else
             File.join "/var/eyrie/cache", spec.name, "eyrie.module.yml"
           end

    begin
      Module.from_path path
    rescue ex : YAML::ParseException
      Log.error ex, "failed to parse module for '#{spec.name}'"
    rescue ex
      Log.error ex
    end
  end

  def self.write_lockfile(mods : Array(Module)) : Nil
    spec = LockSpec.new
    spec.modules = mods.map &.to_spec

    File.write LOCK_PATH, spec.to_yaml
  rescue ex
    Log.error ex, "failed to save lockfile"
  end
end

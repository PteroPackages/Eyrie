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

  def self.run_local(path : String, version : String, no_lock : Bool) : Nil
    Util.run_prerequisites

    Log.fatal [
      "source module file not found:", path,
      "make sure you are using the correct relative or absolute path"
    ] unless File.exists? path

    Log.fatal [
      "invalid version requirement format",
      "version requirements must be in the major.minor.patch format"
    ] unless version.matches? /^(?:\*|\d+\.\d+\.\d+)$/

    start = Time.monotonic
    begin
      mod = Module.from_path path
      mod.validate
    rescue ex : YAML::ParseException
      Log.fatal ex, "failed to parse local module:"
    rescue ex
      Log.fatal ex
    end

    return unless LocalResolver.run mod
    Log.info "installing 1 module"

    proc = Processor.new "/var/www/pterodactyl"
    Log.fatal "no modules could be resolved" unless proc.run mod
    write_lockfile([mod]) unless no_lock

    taken = Time.monotonic - start
    Log.info "installed 1 module in #{taken.milliseconds}ms"
  end

  def self.install(spec : ModuleSpec) : Module?
    res = if spec.source.type.local?
            LocalResolver.run spec
          else
            GitResolver.run spec
          end
    return unless res

    path = if spec.source.type.local?
             File.expand_path File.join(Dir.current, spec.source.uri)
           else
             File.join "/var/eyrie/cache", spec.name, "eyrie.module.yml"
           end

    begin
      mod = Module.from_path path
      unless mod.name == spec.name
        raise "mismatched module names: expected '#{spec.name}'; got '#{mod.name}'"
      end
      mod
    rescue ex : YAML::ParseException
      Log.error ex, "failed to parse module for '#{spec.name}'"
    rescue ex : File::Error
      Log.error "module file not found for '#{spec.name}'"
    rescue ex
      Log.error ex
    end
  end

  def self.write_lockfile(mods : Array(Module)) : Nil
    spec = LockSpec.new LOCK_VERSION, [] of ModuleSpec
    spec.modules = mods.map &.to_spec

    File.write LOCK_PATH, spec.to_yaml
  rescue ex
    Log.error ex, "failed to save lockfile"
  end
end

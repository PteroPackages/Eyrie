require "file_utils"
require "./package"
require "./processor"
require "./resolvers/*"

module Eyrie::Installer
  def self.run(specs : Array(ModuleSpec), lock : Bool) : Nil
    Log.vinfo "checking panel availability"
    proc = Processor.new "/var/www/pterodactyl"

    Log.vinfo "checking cache availability"
    unless Dir.exists? "/var/eyrie/cache"
      Log.vwarn "cache directory not found, attempting to create"
      begin
        Dir.mkdir_p "/var/eyrie/cache"
      rescue ex
        Log.fatal ex, "failed to create cache directory"
      end
    end

    unless Dir.empty? "/var/eyrie/cache"
      Log.vinfo "cache directory not empty, attempting clean"
      begin
        FileUtils.rm_rf "/var/eyrie/cache"
      rescue ex
        Log.warn ex, "failed to clean cache path"
      end
    end

    Log.vinfo "checking git availability"
    begin
      `git --version`
    rescue ex
      Log.fatal ex, "git is required for this operation"
    end

    specs.each do |spec|
      Log.vinfo "validating module spec '#{spec.name}'"
      spec.validate
    rescue ex
      Log.error "failed to validate module spec '#{spec.name}'"
      Log.fatal ex
    end

    start = Time.monotonic
    modules = [] of Module
    specs.each do |spec|
      if mod = install spec
        modules << mod
      end
    end

    Log.fatal "no modules could be resolved" if modules.empty?
    Log.info "installing #{modules.size} module#{"s" if modules.size > 1}"

    done = [] of Module
    modules.each do |mod|
      done << mod if proc.run mod
    end

    write_lockfile(done) if lock

    taken = Time.monotonic - start
    Log.info "installed #{done.size} module#{"s" if done.size > 1} in #{taken.nanoseconds}ms"
  end

  private def self.install(spec : ModuleSpec) : Module?
    res = if spec.source.type.local?
      LocalResolver.run spec
    else
      GitResolver.run spec
    end
    return unless res

    unless spec.source.type.local?
      path = File.join "/var/eyrie/cache", spec.name, "eyrie.module.yml"
      unless File.exists? path
        Log.error "module file not found for '#{spec.name}'"
        return
      end

      Module.from_path path
    else
      begin
        Module.from_path MOD_PATH
      rescue ex : YAML::ParseException
        Log.error ex, "failed to parse module for '#{spec.name}'"
      rescue ex
        Log.error ex
      end
    end
  end

  private def self.write_lockfile(mods : Array(Module)) : Nil
    spec = LockSpec.new
    spec.modules = mods.map &.to_spec

    File.write LOCK_PATH, spec.to_yaml
  rescue ex
    Log.error ex, "failed to save lockfile"
  end
end

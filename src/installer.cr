require "./processor"
require "./resolvers/*"

module Eyrie::Installer
  def self.run(specs : Array(ModuleSpec), lock : Bool) : Nil
    check_prerequisites

    specs.each do |spec|
      begin
        spec.validate
      rescue ex
        Log.error { "failed to validate module spec '#{spec.name}':" }
        Log.fatal(ex) { }
      end
    end

    start = Time.monotonic
    modules = [] of Module
    specs.each do |spec|
      if mod = install spec
        modules << mod
      end
    end

    if modules.empty?
      Log.fatal { "no modules could be resolved" }
    end

    Processor.check_panel
    done = 0

    modules.each do |mod|
      if Processor.exec mod
        Log.info { "module #{mod.name} installed" }
        done += 1
      end
    end

    taken = Time.monotonic - start
    Log.info { "installed #{done} modules in #{taken.nanoseconds}ms" }
  end

  private def self.check_prerequisites : Nil
    Log.vinfo { "checking panel availability" }
    unless Dir.exists? "/var/www/pterodactyl"
      Log.fatal { "panel root directory not found (path: /var/www/pterodactyl)" }
    end

    Log.vinfo { "checking cache availability" }
    unless Dir.exists? "/var/eyrie/cache"
      Log.vinfo { "cache directory not found; attempting to create" }
      begin
        Dir.mkdir_p "/var/eyrie/cache"
      rescue ex
        Log.fatal(ex) { "failed to create cache directory" }
      end
    end

    unless Dir.empty? "/var/eyrie/cache"
      Log.vinfo { "cache directory not empty; attempting clean" }
      Dir.glob("/var/eyrie/cache")[1..].each do |path|
        begin
          File.delete path
        rescue
          Log.vwarn { "failed to remove cached path:" }
          Log.vwarn { path }
        end
      end
    end

    Log.vinfo { "checking git availability" }
    begin
      `git --version`
    rescue ex
      Log.fatal(ex) { "git is required for this operation" }
    end

    Log.vinfo { "prerequisite checks completed" }
  end

  private def self.install(spec : ModuleSpec) : Module?
    res = if spec.source.type.local?
      LocalResolver.run spec
    else
      GitResolver.run spec
    end

    return unless res

    path = Processor::CACHE_PATH / spec.name / "eyrie.module.yml"
    unless File.exists? path
      Log.error { "module file not found for '#{spec.name}'" }
      return
    end

    mod = uninitialized Module
    begin
      data = File.read path
      mod = Module.from_yaml data
    rescue ex : YAML::ParseException
      Log.error(ex) { "failed to parse module file" }
    rescue ex
      Log.error(ex) { }
    end

    unless mod.name == spec.name
      Log.error { "mismatched module names" }
      Log.error { "expected '#{spec.name}'; got '#{mod.name}'" }
      return
    end

    mod
  end
end

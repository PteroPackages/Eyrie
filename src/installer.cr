module Eyrie::Installer
  def self.run_local(root : String, source : String, version : Version) : Nil
    path = Path[source].normalize
    path /= "eyrie.yml" if File.directory? path

    unless File.exists? path
      Log.fatal "no eyrie.yml file found for local module"
    end

    mod = Module.from_path path.to_s
    Log.info "found module '#{mod.name}'"

    begin
      mod.validate
    rescue ex : Error
      Log.fatal ex.format
    rescue ex
      Log.fatal ex, "failed to validate module '#{mod.name}'"
    end

    install root, mod, version
  end

  def self.run(root : String, source : String, version : Version) : Nil
  end

  private def self.install(root : String, mod : Module, version : Version) : Nil
    Log.vinfo "checking version compatibility"

    if (version <=> mod.version) == -1
      Log.fatal ["version requirement failed", "expected module version #{version}; got #{mod.version}"]
    end
    Log.info "installing module version #{mod.version}"

    if mod.source.not_nil!.type.local?
      Resolver.pull_from_local mod
    else
      Resolver.pull_from_git mod
    end

    dir = File.join "/var/eyrie/cache", mod.name
    Dir.cd(dir) do
      parts, includes = mod.files.includes.partition &.includes? '*'
      includes += parts.flat_map { |p| Dir.glob(p) } unless parts.empty?

      parts, excludes = mod.files.excludes.partition &.includes? '*'
      includes += parts.flat_map { |p| Dir.glob(p) } unless parts.empty?

      includes.reject! &.in? excludes
      Log.fatal "no included files were resolved" if includes.empty?

      begin
        Util.copy_all includes, root
      rescue ex
        Log.fatal ex, "failed to move module files to destination"
      end
    end
  end
end

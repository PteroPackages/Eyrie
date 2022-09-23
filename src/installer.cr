module Eyrie::Installer
  extend self

  def run_local(source : String, version : String) : Nil
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

    Log.vinfo "checking version compatibility"
    if (SemanticVersion.parse(version) <=> mod.version) == -1
      Log.fatal [
        "version requirement failed",
        "expected module version #{version}; got #{mod.version}"
      ]
    end

    # copy files to cache
    # install from cache
    # write to lockfile
  end

  def run(source : String, version : String) : Nil
  end
end

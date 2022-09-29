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

    unless version.accepts? mod.version
      Log.fatal ["version requirement failed", "expected module version #{version}; got #{mod.version}"]
    end
    Log.info "installing version #{mod.version}"

    begin
      if mod.source.not_nil!.type.local?
        Resolver.pull_from_local mod
      else
        Resolver.pull_from_git mod
      end
    rescue ex : Error
      Log.fatal ex.format
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
        Util.copy includes, root
      rescue ex
        Log.fatal ex, "failed to move module files to destination"
      end
    end

    if deps = mod.deps.install
      install_dependencies deps, root
    end

    if deps = mod.deps.remove
      remove_dependencies deps, root
    end
  end

  private def self.install_dependencies(deps : CmdDepSpec, root : String) : Nil
    if composer = deps.composer
      unless Process.find_executable "composer"
        Log.error "cannot install php dependencies without composer"
        return
      end

      composer.each do |name, version|
        Log.info "installing dependency '#{name}'"
        dep = name + (version == "*" ? "" : ":#{version}")

        if ex = exec "composer require #{dep}", root
          Log.error ex, "failed to install composer dependency '#{name}'"
        end
      end
    end

    if npm = deps.npm
      unless Process.find_executable "npm"
        Log.error "cannot install node dependencies without npm"
        return
      end

      npm.each do |name, version|
        Log.info "installing dependency '#{name}'"
        dep = name + (version == "*" ? "" : ":#{version}")

        if ex = exec "npm install #{dep}", root
          Log.error ex, "failed to install npm dependency '#{name}'"
        end
      end
    end
  end

  private def self.remove_dependencies(deps : CmdDepSpec, root : String) : Nil
    if composer = deps.composer
      unless Process.find_executable "composer"
        Log.error "cannot remove php dependencies without composer"
        return
      end

      composer.keys.each do |name|
        Log.info "removing dependency '#{name}'"
        if ex = exec "composer remove #{name}", root
          Log.error ex, "failed to remove composer dependency '#{name}'"
        end
      end
    end

    if npm = deps.npm
      unless Process.find_executable "npm"
        Log.error "cannot remove node dependencies without npm"
        return
      end

      npm.keys.each do |name|
        Log.info "removing dependency '#{name}'"
        if ex = exec "npm uninstall #{name}", root
          Log.error ex, "failed to remove npm dependency '#{name}'"
        end
      end
    end
  end

  private def self.exec(command : String, root : String) : Exception?
    err = IO::Memory.new
    Process.run command, shell: true, error: err, chdir: root
    unless (msg = err.to_s).empty?
      Exception.new msg.lines.first
    end
  rescue ex
    ex
  end
end

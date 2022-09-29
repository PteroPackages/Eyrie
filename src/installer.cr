module Eyrie::Installer
  def self.run_local(root : String, source : String, version : Version) : Nil
    path = Path[source].normalize
    path /= "eyrie.yml" if File.directory? path

    unless File.exists? path
      Log.fatal "No eyrie.yml file found for local module"
    end

    mod = Module.from_path path.to_s
    Log.info "Found module '#{mod.name}'"
    Log.vinfo "validating module..."

    begin
      mod.validate
    rescue ex : Error
      Log.fatal ex.format
    rescue ex
      Log.fatal ex, "Failed to validate module '#{mod.name}'"
    end

    install root, mod, version
  end

  def self.run(root : String, source : String, version : Version) : Nil
  end

  private def self.install(root : String, mod : Module, version : Version) : Nil
    Log.vinfo "checking version compatibility"

    unless version.accepts? mod.version
      Log.fatal ["Version requirement failed", "Expected module version #{version}; got #{mod.version}"]
    end

    Log.info ["Installing version #{mod.version}", "Resolving #{mod.source.type} sources..."]

    begin
      if mod.source.type.local?
        Resolver.pull_from_local mod
      else
        Resolver.pull_from_git mod
      end
    rescue ex : Error
      Log.fatal ex.format
    end

    dir = File.join "/var/eyrie/cache", mod.name
    Dir.cd(dir) do
      Log.vinfo "collecting included and excluded files"

      parts, includes = mod.files.includes.partition &.includes? '*'
      includes += parts.flat_map { |p| Dir.glob(p) } unless parts.empty?

      parts, excludes = mod.files.excludes.partition &.includes? '*'
      includes += parts.flat_map { |p| Dir.glob(p) } unless parts.empty?

      includes.reject! &.in? excludes
      Log.fatal "No included files were resolved" if includes.empty?

      Log.info "Moving module files into panel..."
      Log.vinfo [
        "included #{includes.size} files, excluded #{excludes.size} files",
        "source: #{dir}",
        "destination: #{root}"
      ]

      begin
        Util.copy includes, root
      rescue ex
        Log.fatal ex, "Failed to move module files to destination"
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
      Log.info "Checking composer install dependencies..."
      unless Process.find_executable "composer"
        Log.error "Cannot install php dependencies without composer"
        return
      end

      composer.each do |name, version|
        Log.info "Installing dependency '#{name}'"
        dep = name + (version == "*" ? "" : ":#{version}")

        if ex = exec "composer require #{dep}", root
          Log.error ex, "Failed to install composer dependency '#{name}'"
        end
      end
    end

    if npm = deps.npm
      Log.info "Checking npm install dependencies..."
      unless Process.find_executable "npm"
        Log.error "Cannot install node dependencies without npm"
        return
      end

      npm.each do |name, version|
        Log.info "Installing dependency '#{name}'"
        dep = name + (version == "*" ? "" : ":#{version}")

        if ex = exec "npm install #{dep}", root
          Log.error ex, "Failed to install npm dependency '#{name}'"
        end
      end
    end
  end

  private def self.remove_dependencies(deps : CmdDepSpec, root : String) : Nil
    if composer = deps.composer
      Log.info "Checking composer remove dependencies..."
      unless Process.find_executable "composer"
        Log.error "Cannot remove php dependencies without composer"
        return
      end

      composer.keys.each do |name|
        Log.info "Removing dependency '#{name}'"
        if ex = exec "composer remove #{name}", root
          Log.error ex, "Failed to remove composer dependency '#{name}'"
        end
      end
    end

    if npm = deps.npm
      Log.info "Checking npm remove dependencies..."
      unless Process.find_executable "npm"
        Log.error "Cannot remove node dependencies without npm"
        return
      end

      npm.keys.each do |name|
        Log.info "Removing dependency '#{name}'"
        if ex = exec "npm uninstall #{name}", root
          Log.error ex, "Failed to remove npm dependency '#{name}'"
        end
      end
    end
  end

  private def self.exec(command : String, root : String) : Exception?
    Log.vinfo "exec: " + command

    err = IO::Memory.new
    Process.run command, shell: true, error: err, chdir: root
    unless (msg = err.to_s).empty?
      Exception.new msg.lines.first
    end
  rescue ex
    ex
  end
end

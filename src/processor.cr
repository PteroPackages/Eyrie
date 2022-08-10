require "semantic_compare"
require "semantic_version"
require "./package"

module Eyrie::Processor
  PANEL_PATH = Path["/var/www/pterodactyl"]
  CACHE_PATH = Path["/var/eyrie/cache"]

  def self.get_panel_version : String
    config = PANEL_PATH / "config" / "app.php"
    unless File.exists? config
      Log.error { "panel 'app.php' config file not found" }
      Log.fatal { "cannot install modules; terminating" }
    end

    info = File.read config
    info =~ /'version' \=\> '(.*)'/
    unless $1?
      Log.error { "could not get panel version from config" }
      Log.fatal { "cannot install modules; terminating" }
    end

    if $1 == "canary"
      Log.error { "canary builds of the panel are not supported" }
      Log.fatal { "please install an official version of the panel to use this application" }
    end

    $1
  end

  def self.run(mod : Module, version : String) : Bool
    begin
      mod.validate
    rescue ex
      Log.error(ex) { "failed validating module '#{mod.name}'" }
      return false
    end

    if mod.authors.empty?
      Log.warn { "no authors set for the package" }
    else
      mod.authors.each do |author|
        Log.warn { "missing name for author" } if author.name.empty?
        Log.warn { "missing contact for author" } if author.contact.empty?
      end
    end

    valid : String? = nil
    if mod.supports.any? { |v| v.match %r[[*~<>=^]+] }
      parsed = SemanticVersion.try &.parse version
      unless parsed
        Log.error { "failed to parse panel version" }
        return false
      end

      valid = mod.supports.find { |v| SemanticCompare.simple_expression parsed, v }
    else
      valid = mod.supports.find { |v| v == version }
    end

    unless valid
      Log.error { "this module does not support panel version #{$1}" }
      return false
    end

    resolve_files mod
    install_deps mod.deps
    exec_postinstall mod.postinstall

    true
  end

  private def self.resolve_files(mod : Module) : Nil
    Log.vinfo { "resolving module files" }
    loc = CACHE_PATH / mod.name

    Dir.cd(loc) do
      includes = Dir.glob mod.files.include
      excludes = Dir.glob mod.files.exclude
      includes.reject! { |f| f.in? excludes }
      if includes.empty?
        Log.error { "no included files were resolved" }
        return false
      end

      Log.info { "moving included files" }

      includes.each do |file|
        dest = PANEL_PATH / file

        Log.vinfo { "source: #{file}" }
        Log.vinfo { "dest: #{dest}" }

        if File.exists? dest
          Log.vinfo { "destination exists; attempting overwrite" }
          data = File.read file
          begin
            File.write dest, data
          rescue ex
            Log.error(ex) { "failed overwriting destination path" }
          end
        else
          begin
            File.copy file, dest
          rescue ex
            Log.error(ex) { "failed to copy file to destination" }
          end
        end
      end
    end
  end

  private def self.install_deps(deps : Deps) : Nil
    install = deps.install
    return unless install

    unless install.composer.empty?
      if ex = exec "composer --version"
        Log.error(ex) { "cannot install php dependencies without composer" }
      end

      install.composer.each do |name, version|
        if ex = exec %(composer require "#{name}" #{version})
          Log.error(ex) { "dependency '#{name}' failed to install" }
        end
      end
    end

    unless install.npm.empty?
      if ex = exec "npm --version"
        Log.error(ex) { "cannot install node dependencies without npm" }
      end

      install.npm.each do |name, version|
        name += "@#{version}" unless version.empty?
        if ex = exec "npm install --no-fund #{name}"
          Log.error(ex) { "dependency '#{name}' failed to install" }
        end
      end
    end
  end

  private def self.exec_postinstall(scripts : Array(String)) : Nil
    if scripts.empty?
      Log.info { "no postinstall scripts to execute" }
      return
    end

    scripts.each_with_index do |script, i|
      Log.vinfo { script }
      if ex = exec script
        Log.error(ex) { "script #{i+1} failed: #{ex.message}" }
      end

      Log.vinfo { "script #{i+1}: exited (#{$?.success?}" }
    end
  end

  private def self.exec(command : String) : Exception?
    begin
      Process.exec command, shell: true
    rescue ex
      ex
    end
  end
end

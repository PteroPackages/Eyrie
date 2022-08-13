require "semantic_compare"

module Eyrie
  class Processor
    @version        : SemanticVersion
    @panel_path     : String
    @composer_deps  : Hash(String, String)
    @npm_deps       : Hash(String, String)

    def initialize(@panel_path)
      unless Dir.exists? @panel_path
        Log.fatal "panel root location not found (path: #{@panel_path})"
      end

      config = File.join @panel_path, "config", "app.php"
      unless File.exists? config
        Log.fatal [
          "panel 'app.php' config file not found",
          "this file is required for installing modules"
        ]
      end

      info = File.read config
      info =~ /'version' => '(.*)'/
      unless $1?
        Log.fatal [
          "could not get panel version from config",
          "please ensure a valid panel version is set in your config"
        ]
      end

      if $1 == "canary"
        Log.fatal [
          "canary builds of the panel are not supported",
          "please install an official version of the panel to use this application"
        ]
      end

      @version = uninitialized SemanticVersion # type-safety
      begin
        @version = SemanticVersion.parse $1
      rescue ex : ArgumentError
        Log.fatal ex, "failed to parse panel version"
      end
      Log.vinfo "using panel version #{@version}"

      @composer_deps = {} of String => String
      @npm_deps = {} of String => String
    end

    def run(mod : Module) : Bool
      Log.warn "no authors set for the package" if mod.authors.empty?

      # TODO: attempt to fix invalid version formats (+.0)?
      # still warn about them
      mod.supports =~ /[*~<|>=^]*\d+\.\d+(\.\d+)?[*~<|>=^]*/
      unless $1?
        Log.error [
          "cannot accept supported version requirement '#{mod.supports}'",
          "version requirements must be in the major.minor.match format"
        ]
        return false
      end

      valid = false

      if mod.supports.matches? /[*~<|>=^]+/
        if mod.supports.includes? '|'
          valid = SemanticCompare.complex_expression @version, mod.supports
        else
          valid = SemanticCompare.simple_expression @version, mod.supports
        end
      end

      unless valid
        Log.error [
          "panel version #{@version} is not supported by this module",
          "supported requirement: #{mod.supports}"
        ]
        return false
      end

      return false unless resolve_files mod
      resolve_dependencies mod.deps
      exec_postinstall mod.postinstall
      save_module mod

      Log.info "module '#{mod.name}' installed"
      true
    end

    private def resolve_files(mod : Module) : Bool
      Log.vinfo "resolving module files"
      loc = File.join "/var/eyrie/cache", mod.name

      Dir.cd(loc) do
        includes = Dir.glob mod.files.include
        excludes = Dir.glob mod.files.exclude
        includes.reject! &.in? excludes

        if includes.empty?
          Log.error "no included files were resolved"
          return false
        end

        Log.vinfo "moving module files"
        begin
          FileUtils.cp includes, @panel_path
        rescue ex
          Log.error ex, "failed to move module files to destination"
          Log.vinfo ["failed:"] + includes
          return false
        end
      end

      true
    end

    private def resolve_dependencies(deps : Deps) : Nil
      if install = deps.install
        # install = parse_non_conflict install

        unless install.composer.empty?
          if ex = exec "composer --version"
            Log.error ex, "cannot install php dependencies without composer"
            return
          end

          install.composer.each do |name, version|
            name += ":" + version unless version.empty? || version == "*"
            if ex = exec %(composer require "#{name}")
              Log.error ex, "dependency '#{name}' failed to install"
            else
              @composer_deps[name] = version
            end
          end
        end

        unless install.npm.empty?
          if ex = exec "npm --version"
            Log.error ex, "cannot install node dependencies without npm"
            return
          end

          install.npm.each do |name, version|
            name += "@" + version unless version.empty? || version == "*"
            if ex = exec "npm install #{name}"
              Log.error ex, "dependency '#{name}' failed to install"
            else
              @npm_deps[name] = version
            end
          end
        end
      end

      # TODO: remove dependencies
    end

    private def exec_postinstall(scripts : Array(String)) : Nil
      return if scripts.empty?
      Log.info "running postinstall scripts"

      scripts.each_with_index do |script, i|
        Log.vinfo "#{i+1}: #{script}"
        if ex = exec script
          Log.error ex, "script #{i+1} failed: #{ex.message}"
        end
        Log.vinfo "script #{i+1} exited: #{$?.exit_code}"
      end
    end

    private def save_module(mod : Module) : Nil
      path = File.join "/var/eyrie/save", mod.name + ".save.yml"

      begin
        File.write path, mod.to_yaml
      rescue ex
        Log.warn ex, "failed to save module '#{mod.name}'"
      end
    end

    private def exec(command : String) : Exception?
      Log.vinfo command
      Process.exec command, shell: true, chdir: "/var/www/pterodactyl"
    rescue ex
      ex
    end
  end
end

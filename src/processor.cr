module Eyrie
  class Processor
    @version : SemanticVersion
    @panel_path : String

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
    end

    def run(mod : Module) : Bool
      Log.warn "no authors set for the package" if mod.authors.empty?

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
      install_dependencies mod.deps
      exec_postinstall mod.postinstall
      save_module mod

      Log.info "module '#{mod.name}' installed"
      true
    end

    private def resolve_files(mod : Module) : Bool
      Log.vinfo "resolving module files"
      loc = File.join "/var/eyrie/cache", mod.name

      Dir.cd(loc) do
        parts, abs = mod.files.includes.partition &.includes? '*'
        includes = abs
        includes += parts.flat_map { |p| Dir.glob p } unless parts.empty?

        parts, abs = mod.files.excludes.partition &.includes? '*'
        excludes = abs
        excludes += parts.flat_map { |p| Dir.glob p } unless parts.empty?

        includes.reject! &.in? excludes
        includes.reject! { |p| Dir.exists? p }

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

    # TODO: add info logs
    private def install_dependencies(deps : Deps) : Nil
      return unless install = deps.install

      if composer = install.composer
        unless composer.empty?
          unless path = Process.find_executable "composer"
            Log.error "cannot install php dependencies without composer"
            return
          end

          composer.each do |name, version|
            name += ":" + version unless version.empty? || version == "*"
            if ex = exec "'#{path}' require #{name}"
              Log.error ex, "dependency '#{name}' failed to install"
            end
          end
        end
      end

      if npm = install.npm
        unless npm.empty?
          unless path = Process.find_executable "npm"
            Log.error "cannot install node dependencies without npm"
            return
          end

          npm.each do |name, version|
            name += "@" + version unless version.empty? || version == "*"
            if ex = exec "'#{path}' install #{name}"
              if ex.message.try &.includes? "bash\\r" # CRLF issue
                Log.error [
                  "cannot execute npm on this system (invalid format)",
                  "skipping all npm dependency installations"
                ]
                return
              else
                Log.error ex, "dependency '#{name}' failed to install"
              end
            end
          end
        end
      end
    end

    # TODO
    # private def remove_depdendencies(deps : Deps) : Nil

    private def exec_postinstall(scripts : Array(String)) : Nil
      return if scripts.empty?
      Log.info "running postinstall scripts"

      scripts.each_with_index do |script, i|
        Log.vinfo "#{i + 1}: #{script}"
        if ex = exec script
          Log.error ex, "script #{i + 1} failed: #{ex.message}"
        end
        Log.vinfo "script #{i + 1} exited: #{$?.exit_code}"
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
      err = IO::Memory.new

      Process.run command, error: err, chdir: "/var/www/pterodactyl", shell: true
      raise err.to_s unless err.empty?
    rescue ex
      ex
    end
  end
end

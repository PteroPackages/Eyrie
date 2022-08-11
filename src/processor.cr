require "semantic_compare"
require "semantic_version"

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
      info =~ %r['version' => '(.*)']
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

      valid = false
      if mod.supports.any? { |v| v.match %r[[*~<|>=^]+] }
        mod.supports.each do |v|
          if v.includes? '|'
            valid = SemanticCompare.complex_expression @version, v
          else
            valid = SemanticCompare.simple_expression @version, v
          end

          break if valid
        end
      else
        valid = valid.in? mod.supports
      end

      unless valid
        Log.error [
          "panel version #{@version} is not supported by this module",
          %(supported: #{mod.supports.join(" or ")})
        ]
        return false
      end

      return false unless resolve_files mod
      resolve_dependencies mod.deps
      exec_postinstall mod.postinstall

      Log.info "module '#{mod.name}' installed"
      true
    end

    private def resolve_files(mod : Module) : Bool
      Log.vinfo "resolving module files"
      loc = File.join "/var/eyrie/cache", mod.name

      Dir.cd(loc) do
        includes = Dir.glob mod.files.include
        excludes = Dir.glob mod.files.exclude
        includes.reject! { |f| f.in? excludes }

        if includes.empty?
          Log.error "no included files were resolved"
          return false
        end

        Log.info "moving module files"
        includes.each do |file|
          dest = File.join @panel_path, file

          Log.vinfo ["source: #{file}", "dest:   #{dest}"]

          begin
            File.rename file, dest
          rescue ex
            Log.error ex, "failed moving file to destination"
          end
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
            name += ":" + version unless version.empty?
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
            name += "@" + version unless version.empty?
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

    # private def parse_non_conflict(spec : CmdDepSpec) : CmdDepSpec
    #   res = CmdDepSpec.new

    #   spec.composer.each do |name, version|
    #     if v = @composer_deps[name]?
    #       Log.warn { "existing php dependency '#{name}' found" }

    #       valid = SemanticCompare.try(&.simple_expression version) || false
    #       unless valid
    #         Log.warn { "dependency '#{name}:#{version}' conflicts with dependency '#{name}:#{v}'" }
    #         Log.warn { "cannot use dependency '#{name}'" }
    #         next
    #       end
    #     end

    #     res.composer[name] = version
    #   end

    #   spec.npm.each do |name, version|
    #     if v = @npm_deps[name]?
    #       Log.warn { "existing node dependency '#{name}' found" }

    #       valid = SemanticCompare.try(&.simple_expression version) || false
    #       unless valid
    #         Log.warn { "dependency '#{name}@#{version}' conflicts with dependency '#{name}:#{v}'" }
    #         Log.warn { "cannot use dependency '#{name}'" }
    #         next
    #       end
    #     end

    #     res.composer[name] = version
    #   end

    #   res
    # end

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

    private def exec(command : String) : Exception?
      Log.vinfo command
      Process.exec command, shell: true, chdir: "/var/www/pterodactyl"
    rescue ex
      ex
    end
  end
end

module Eyrie::Commands
  class InstallCommand < CLI::Command
    def setup : Nil
      @name = "install"
      @description = "Installs modules from a source or lockfile."
      @usage << "install [-s|--source <url>] [-L|--no-lock] [-v|--verbose] [--version <v>] [options]"

      add_option "no-lock", short: "L", desc: "don't save the modules in the lockfile"
      add_option "source", short: "s", desc: "the url or path to the module source", kind: :string
      add_option "type", short: "t", desc: "the type of source to install from", kind: :string, default: "local"
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      add_option "version", desc: "the version of the module to install", kind: :string, default: "*"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.no_color if options.has? "no-color"

      {% if flag?(:win32) %}
        Log.fatal "this command cannot be used on windows systems yet"
      {% end %}

      Log.trace if options.has? "trace"
      Log.verbose if options.has? "verbose"

      if source = options.get "source"
        name = source.split('/').pop.downcase.underscore
        version = options.get! "version"

        if options.get!("type") == "local"
          Installer.run_local name, version, options.has?("no-lock")
        else
          spec = ModuleSpec.new name, version, source, options.get!("type")
          Installer.run [spec], options.has?("no-lock")
        end
      else
        begin
          lock = LockSpec.from_path LOCK_PATH
          Installer.run lock.modules, options.has?("no-lock")
        rescue File::Error
          Log.fatal ["lockfile path does not exist:", LOCK_PATH]
        rescue ex
          Log.fatal ex, "failed to parse lockfile:"
        end
      end
    end
  end
end

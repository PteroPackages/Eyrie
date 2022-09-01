module Eyrie::Commands
  class InstallCommand < CLI::Command
    def setup : Nil
      @name = "install"
      @description = "Installs modules from a source or lockfile."
      @usage << "install [-s|--source <url>] [-L|--no-lock] [-v|--verbose] [options]"

      add_option "no-lock", short: "L", desc: "don't save the modules in the lockfile"
      add_option "source", short: "s", desc: "the url or path to the module source", kind: :string
      add_option "type", short: "t", desc: "the type of source to install from", kind: :string, default: "local"
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.no_color if options.has? "no-color"

      {% if flag?(:win32) %}
        Log.fatal "this command cannot be used on windows systems yet"
      {% end %}

      Log.trace if options.has? "trace"
      Log.verbose if options.has? "verbose"

      modules = [] of ModuleSpec

      source = options.get "source"
      if source
        begin
          name = source.split('/').pop.downcase.underscore
          modules << ModuleSpec.new(name, "*", source, options.get!("type"))
        rescue ex
          Log.fatal ex
        end
      else
        begin
          spec = LockSpec.from_path LOCK_PATH
          modules += spec.modules
        rescue File::Error
          Log.fatal ["lockfile path does not exist:", LOCK_PATH]
        rescue ex
          Log.fatal ex
        end
      end

      Log.fatal "no modules found to install" if modules.empty?
      Installer.run modules, options.has?("no-lock")
    rescue ex
      Log.fatal ex
    end
  end
end

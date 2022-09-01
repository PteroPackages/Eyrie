module Eyrie::Commands
  class UpgradeCommand < CLI::Command
    def setup : Nil
      @name = "upgrade"
      @description = "Upgrades installed modules by name or from a lockfile."
      @usage << "upgrade [name] [-L|--no-lock] [-v|--verbose] [options]"

      add_argument "name", desc: "the name of the module", required: false
      add_option "no-lock", short: "L", desc: "don't save the modules in the lockfile"
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

      if name = args.get "name"
        mod = List.get_modules.find { |m| m.name == name }
        Log.fatal "module '#{name}' not found or is not installed" unless mod

        Upgrader.run [mod.to_spec], options.has?("no-color")
      else
        begin
          spec = LockSpec.from_path LOCK_PATH
          Upgrader.run spec.modules, options.has?("no-color")
        rescue File::Error
          Log.fatal ["lockfile path does not exist:", LOCK_PATH]
        rescue ex
          Log.fatal ex
        end
      end
    end
  end
end

module Eyrie::Commands
  class UninstallCommand < CLI::Command
    def setup : Nil
      @name = "uninstall"
      @description = "Uninstalls a specified module from the system."
      @usage << "uninstall <name> [-v|--verbose] [options]"

      add_argument "name", desc: "the name of the module", required: true
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

      name = args.get! "name"
      mod = List.get_modules.find { |m| m.name == name }
      Log.fatal "module '#{name}' not found or is not installed" unless mod

      Uninstaller.run mod
    end

    def on_missing_arguments(args)
      Log.fatal "missing required argument '#{args[0]}'"
    end
  end
end

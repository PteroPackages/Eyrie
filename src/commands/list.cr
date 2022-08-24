module Eyrie::Commands
  class ListCommand < CLI::Command
    def setup : Nil
      @name = "list"
      @description = "Lists all installed modules or gets info on a specific module."
      @usage << "list [-n|--name <name>] [-v|--verbose] [options]"

      add_option "name", short: "n", desc: "the name of the module", kind: :string
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.no_color if options.has? "no-color"
      Log.trace if options.has? "trace"
      Log.verbose if options.has? "verbose"

      if name = options.get "name"
        List.get_module_info name
      else
        List.list_modules
      end
    end
  end
end

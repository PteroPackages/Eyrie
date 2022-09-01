module Eyrie::Commands
  class InitCommand < CLI::Command
    def setup : Nil
      @name = "init"
      @description = "Initializes a module file in the current directory."
      @usage << "init [-f|--force] [-l|--lock] [-L|--lock-only] [-s|--skip] [options]"

      add_option "force", short: "f", desc: "force initialize the module"
      add_option "lock", short: "l", desc: "create a lockfile with the module file"
      add_option "lock-only", short: "L", desc: "only create a lockfile"
      add_option "skip", short: "s", desc: "skip the interactive setup"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.no_color if options.has? "no-color"
      Log.trace if options.has? "trace"
      Log.verbose if options.has? "verbose"

      force = options.has? "force"
      lock = options.has? "lock"
      lockonly = options.has? "lock-only"
      skip = options.has? "skip"

      Initializer.init_lockfile(force) if lock || lockonly
      Initializer.init_module_file(force, skip, lock) unless lockonly
    end
  end
end

module Eyrie::Commands
  class InitCommand < CLI::Command
    include Base

    def setup : Nil
      @name = "init"
      @description = "Initializes a module file in the current directory."
      @usage << "create [-f|--force] [-s|--skip] [options]"

      add_option "force", short: "f", desc: "force initialize the module"
      add_option "skip", short: "s", desc: "skip the interactive setup"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      Initializer.run options.has?("force"), options.has?("skip")
    end
  end
end

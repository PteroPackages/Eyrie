module Eyrie::Commands
  class InitCommand < CLI::Command
    include Base

    def setup : Nil
      @name = "init"
      @description = "Initializes a module file in the current directory."
      add_usage "create [-f|--force] [-s|--skip] [options]"

      add_option 'f', "force", desc: "force initialize the module"
      add_option 's', "skip", desc: "skip the interactive setup"
      set_global_options
    end

    def run(args, options) : Nil
      Log.configure options

      Initializer.run options.has?("force"), options.has?("skip")
    end
  end
end

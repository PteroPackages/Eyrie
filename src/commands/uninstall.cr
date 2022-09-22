module Eyrie::Commands
  class UninstallCommand < CLI::Command
    def setup : Nil
      @name = "uninstall"
      @description = "Uninstalls a specified module from the panel."
      @usage << "uninstall <name> [-v|--verbose] [options]"

      add_argument "name", desc: "the name of the module", required: true
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      lock = Lockfile.fetch
      name = args.get! "name"
      mod = lock.modules.find { |m| m.name == name }
      Log.fatal "module '#{name}' not found or is not installed" unless mod

      Uninstaller.run mod
    rescue ex
      Log.fatal ex
    end
  end
end

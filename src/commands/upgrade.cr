module Eyrie::Commands
  class UpgradeCommand < CLI::Command
    def setup : Nil
      @name = "upgrade"
      @description = "Upgrades installed modules by name or from a lockfile."
      @usage << "upgrade [name] [-v|--verbose] [options]"

      add_argument "name", desc: "the name of the module", required: false
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      lock = Lockfile.fetch
      if name = args.get "name"
        mod = lock.modules.find { |m| m.name == name }
        Log.fatal "module '#{name}' not found or is not installed" unless mod

        Upgrader.run mod
      else
        Upgrader.run lock.modules
      end
    rescue ex
      Log.fatal ex
    end
  end
end

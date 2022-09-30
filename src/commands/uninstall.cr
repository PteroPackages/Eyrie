module Eyrie::Commands
  class UninstallCommand < CLI::Command
    def setup : Nil
      @name = "uninstall"
      @description = "Uninstalls a specified module from the panel."
      @usage << "uninstall <name> [-r|--root <dir>] [-v|--verbose] [options]"

      add_argument "name", desc: "the name of the module", required: true
      add_option "root", short: "r", desc: "the root directory of the panel", kind: :string, default: ""
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      lock = Lockfile.fetch
      name = args.get! "name"
      mod = lock.get_saved.find { |m| m.name == name }
      Log.fatal "Module '#{name}' not found or is not installed" unless mod

      root = Util.get_panel_path options.get!("root")
      Log.fatal "Cannot write to panel directory (are you root?)" unless File.writable? root

      taken = Time.measure do
        Uninstaller.run mod, root
        lock.delete mod
      end

      Log.info "Uninstalled module in #{taken.milliseconds}ms"
    ensure
      Util.clear_cache_dir
    end
  end
end

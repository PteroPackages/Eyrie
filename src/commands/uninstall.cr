module Eyrie::Commands
  class UninstallCommand < CLI::Command
    include Base

    def setup : Nil
      @name = "uninstall"
      @description = "Uninstalls a specified module from the panel."
      add_usage "uninstall <name> [-r|--root <dir>] [-v|--verbose] [options]"

      add_argument "name", desc: "the name of the module", required: true
      add_option 'r', "root", desc: "the root directory of the panel", has_value: true, default: ""
      add_option 'v', "verbose", desc: "output debug and verbose logs"
      set_global_options
    end

    def run(args, options) : Nil
      Log.configure options

      lock = Lockfile.fetch
      name = args.get!("name").as_s
      mod = lock.get_saved.find { |m| m.name == name }
      Log.fatal "Module '#{name}' not found or is not installed" unless mod

      root = Util.get_panel_path options.get!("root").as_s
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

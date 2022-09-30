module Eyrie::Commands
  class UpgradeCommand < CLI::Command
    include Base

    def setup : Nil
      @name = "upgrade"
      @description = "Upgrades installed modules by name or that are installed."
      @usage << "upgrade [name] [-r|--root <dir>] [-v|--verbose] [options]"

      add_argument "name", desc: "the name of the module", required: false
      add_option "root", short: "r", desc: "the root directory of the panel", kind: :string, default: ""
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      lock = Lockfile.fetch
      name = args.get "name"

      modules = lock.modules
      modules.select! { |m| m.name == name } if name
      Log.fatal "No modules found to upgrade" if modules.empty?

      Util.run_system_checks
      root = Util.get_panel_path options.get!("root")
      ver = Util.get_panel_version root

      taken = Time.measure do
        Upgrader.run modules, root, ver
      end

      Log.info "Upgraded #{modules.size} module#{"s" if modules.size > 1} in #{taken.milliseconds}ms"
    ensure
      Util.clear_cache_dir
    end
  end
end

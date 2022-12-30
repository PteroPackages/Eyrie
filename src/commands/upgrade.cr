module Eyrie::Commands
  class UpgradeCommand < CLI::Command
    include Base

    def setup : Nil
      @name = "upgrade"
      @description = "Upgrades installed modules by name or that are installed."
      add_usage "upgrade [name] [-r|--root <dir>] [-v|--verbose] [options]"

      add_argument "name", desc: "the name of the module", required: false
      add_option 'r', "root", desc: "the root directory of the panel", has_value: true, default: ""
      add_option 'v', "verbose", desc: "output debug and verbose logs"
      set_global_options
    end

    def run(args, options) : Nil
      Log.configure options

      lock = Lockfile.fetch
      name = args.get("name").try &.as_s

      modules = lock.modules
      modules.select! { |m| m.name == name } if name
      Log.fatal "No modules found to upgrade" if modules.empty?

      Util.run_system_checks
      root = Util.get_panel_path options.get!("root").as_s
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

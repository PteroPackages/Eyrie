module Eyrie::Commands
  class InstallCommand < CLI::Command
    include Base

    def setup : Nil
      @name = "install"
      @description = "Installs a module from a source or module file."
      add_usage "install <name> [-t|--type <type>] [-v|--verbose] [--version <v>] [-r|--root <dir>] [options]"
      add_usage "install <source> [-t|--type <type>] [-v|--verbose] [--version <v>] [-r|--root <dir>] [options]"

      add_argument "source", desc: "the name or uri to the source", required: true
      add_option 't', "type", desc: "the type of source", has_value: true, default: "local"
      add_option 'v', "verbose", desc: "output debug and verbose logs"
      add_option "version", desc: "the version of the module to install", has_value: true, default: "*"
      add_option 'r', "root", desc: "the root directory of the panel", has_value: true, default: ""
      set_global_options
    end

    def run(args, options) : Nil
      Log.configure options

      type = Source::Type.parse?(options.get!("type").as_s) || Log.fatal [
        "Invalid module source type specified",
        "Expected: local, git, github, gitlab",
      ]
      version = Version.parse options.get!("version").as_s

      Util.run_system_checks
      root = Util.get_panel_path options.get!("root").as_s
      ver = Util.get_panel_version root

      taken = Time.measure do
        if type == Source::Type::Local
          Installer.run_local root, args.get!("source").as_s, version, ver
        else
          Installer.run root, args.get!("source").as_s, version, ver
        end
      end

      Log.info "Installed module in #{taken.milliseconds}ms"
    ensure
      Util.clear_cache_dir
    end
  end
end

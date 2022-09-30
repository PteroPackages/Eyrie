module Eyrie::Commands
  class InstallCommand < CLI::Command
    include Base

    def setup : Nil
      @name = "install"
      @description = "Installs a module from a source or module file."
      @usage << "install <name> [-t|--type <type>] [-v|--verbose] [--version <v>] [-r|--root <dir>] [options]"
      @usage << "install <source> [-t|--type <type>] [-v|--verbose] [--version <v>] [-r|--root <dir>] [options]"

      add_argument "source", desc: "the name or uri to the source", required: true
      add_option "type", short: "t", desc: "the type of source", kind: :string, default: "local"
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      add_option "version", desc: "the version of the module to install", kind: :string, default: "*"
      add_option "root", short: "r", desc: "the root directory of the panel", kind: :string, default: ""
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      type = Source::Type.parse?(options.get!("type")) || Log.fatal [
        "Invalid module source type specified",
        "Expected: local, git, github, gitlab",
      ]
      version = Version.parse options.get!("version")

      Util.run_system_checks
      root = Util.get_panel_path options.get!("root")
      ver = Util.get_panel_version root

      taken = Time.measure do
        if type == Source::Type::Local
          Installer.run_local root, args.get!("source"), version, ver
        else
          Installer.run root, args.get!("source"), version, ver
        end
      end

      Log.info "Installed module in #{taken.milliseconds}ms"
    ensure
      Util.clear_cache_dir
    end
  end
end

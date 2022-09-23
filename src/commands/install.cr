module Eyrie::Commands
  class InstallCommand < CLI::Command
    def setup : Nil
      @name = "install"
      @description = "Installs a module from a source or module file."
      @usage << "install <name> [-t|--type <type>] [-v|--verbose] [--version <v>] [-r|--root <dir>] [options]"
      @usage << "install <source> [-t|--type <type>] [-v|--verbose] [--version <v>] [-r|--root <dir>] [options]"

      add_argument "source", required: true
      add_option "type", short: "t", default: "local"
      add_option "verbose", short: "v"
      add_option "version"
      add_option "root", short: "r"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      type = Source::Type.parse?(args.get!("type")) || Log.fatal [
        "invalid source type specified",
        "expected: local, git, github, gitlab"
      ]

      Util.run_system_checks
      root = Util.get_panel_path(options.get("root") || "")

      if type == Source::Type::Local
        Installer.run_local root, args.get!("source"), options.get!("version")
      else
        Installer.run root, args.get!("source"), options.get!("version")
      end
    end
  end
end

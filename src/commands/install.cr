module Eyrie::Commands
  class InstallCommand < CLI::Command
    def setup : Nil
      @name = "install"
      @description = "Installs a module from a source or module file."
      @usage << "install <name> [-t|--type <type>] [-v|--verbose] [--version <v>] [options]"
      @usage << "install <source> [-t|--type <type>] [-v|--verbose] [--version <v>] [options]"

      add_argument "source", required: true
      add_option "type", short: "t"
      add_option "verbose", short: "v"
      add_option "version"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      type = Source::Type.parse?(args.get!("type")) || Log.fatal [
        "invalid source type specified",
        "expected: local, git, github, gitlab"
      ]

      Util.run_system_checks

      if type == Source::Type::Local
        Installer.run_local args.get!("source"), options.get!("version")
      else
        Installer.run args.get!("source"), options.get!("version")
      end
    end
  end
end

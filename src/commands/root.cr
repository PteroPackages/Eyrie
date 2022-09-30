module Eyrie::Commands
  class RootCommand < CLI::Command
    include Base

    def self.help_template : String
      <<-HELP
      Pterodactyl Module Manager (addons and themes)

      Usage:
              eyrie [options] <command> [arguments]

      Commands:
              init        initializes a module file
              install     installs modules from sources
              list        lists all installed modules
              setup       setup eyrie configurations
              uninstall   uninstalls a module
              upgrade     upgrades installed modules

      Global Options:
              --no-color      disable ansi color codes
              --trace         log error stack traces
              -h, --help      get help information
              -v, --version   get the version for eyrie
      HELP
    end

    def setup
      @name = "root"
      @help_template = self.class.help_template

      # here for functionality, description ignored by help template
      add_option "no-color"
      add_option "trace"
      add_option "help", short: "h"
      add_option "version", short: "v"
    end

    def execute(args, options) : Nil
      if options.has? "version"
        puts "Eyrie version #{VERSION}"
      else
        puts help_template
      end
    end
  end
end

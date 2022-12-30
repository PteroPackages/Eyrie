{% raise "cannot run this application on windows systems yet" if flag?(:win32) %}

require "cli"
require "colorize"
require "ecr/macros"
require "semantic_compare"
require "semantic_version"
require "yaml"

require "./commands/*"
require "./errors"
require "./initializer"
require "./installer"
require "./lock"
require "./log"
require "./module"
require "./resolver"
require "./uninstaller"
require "./upgrader"
require "./util"
require "./version"

Colorize.on_tty_only!

macro set_global_options
  add_option "no-color", desc: "disable ansi color codes"
  add_option "trace", desc: "log error stack traces"
  add_option 'h', "help", desc: "get help information"
end

module Eyrie
  VERSION = "1.0.0-beta"

  class App < CLI::Command
    def setup : Nil
      @name = "eyrie"

      add_option 'v', "version", desc: "get version information"

      add_command Commands::SetupCommand.new
      add_command Commands::InitCommand.new
      add_command Commands::InstallCommand.new
      add_command Commands::ListCommand.new
      add_command Commands::UninstallCommand.new
      add_command Commands::UpgradeCommand.new
    end

    def help_template : String
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
              -v, --version   get version information
      HELP
    end

    def run(args, options) : Nil
      if options.has? "version"
        puts "Eyrie version #{VERSION}"
      else
        puts help_template
      end
    end
  end
end

begin
  Eyrie::App.new.execute ARGV
rescue Eyrie::SystemExit
rescue ex
  Eyrie::Log.error ex
  Eyrie::Log.fatal ["", "This may be a bug with Eyrie, please report it to the PteroPackages team"]
end

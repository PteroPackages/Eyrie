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
  add_option "help", short: "h", desc: "get help information"
end

module Eyrie
  VERSION = "1.0.0-beta"

  def self.run : Nil
    app = CLI::Application.new
    app.help_template = Commands::RootCommand.help_template

    app.add_command Commands::RootCommand, default: true
    app.add_command Commands::SetupCommand
    app.add_command Commands::InitCommand
    app.add_command Commands::InstallCommand
    app.add_command Commands::ListCommand
    app.add_command Commands::UninstallCommand
    app.add_command Commands::UpgradeCommand

    app.run ARGV
  end
end

begin
  Eyrie.run
rescue Eyrie::SystemExit
rescue ex
  Eyrie::Log.error ex
  Eyrie::Log.fatal ["", "This may be a bug with Eyrie, please report it to the PteroPackages team"]
end

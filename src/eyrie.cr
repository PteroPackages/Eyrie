{% if flag?(:win32) %}
  {% raise "cannot run this application on windows systems yet" %}
{% end %}

require "cli"
require "colorize"
require "semantic_compare"
require "semantic_version"
require "yaml"

require "./commands/*"
require "./initializer"
require "./installer"
require "./lock"
require "./log"
require "./module"
require "./uninstaller"
require "./upgrader"
require "./util"

Colorize.on_tty_only!

macro set_global_options
  add_option "no-color", desc: "disable ansi color codes"
  add_option "trace", desc: "log error stack traces"
  add_option "help", short: "h", desc: "get help information"
end

module Eyrie
  VERSION = "0.2.0"

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
rescue ex
  Eyrie::Log.error ex
  Eyrie::Log.fatal ["", "This may be a bug with Eyrie, please report it to the PteroPackages team"]
end

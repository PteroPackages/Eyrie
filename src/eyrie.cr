require "cli"
require "colorize"
require "file_utils"
require "semantic_compare"
require "semantic_version"

require "./commands/*"
require "./initializer"
require "./installer"
require "./list"
require "./log"
require "./package"
require "./processor"
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
  VERSION      = "0.1.0"
  LOCK_VERSION = 1
  MOD_PATH     = File.join Dir.current, "eyrie.module.yml"
  LOCK_PATH    = File.join Dir.current, "eyrie.lock"

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
  Eyrie::Log.trace
  Eyrie::Log.fatal ex
end

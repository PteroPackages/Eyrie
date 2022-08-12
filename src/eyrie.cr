require "clim"
require "./initializer"
require "./installer"
require "./log"
require "./package"

macro set_default_opts
  option "--no-color", type: Bool, desc: "disable ansi color codes", default: false
  option "--trace", type: Bool, desc: "log error stack trace", default: false

  macro help_macro
    option "-h", "--help", type: Bool, desc: "sends this help message", default: false
  end
end

module Eyrie
  VERSION = "0.1.0"
  LOCK_VERSION = 1
  MOD_PATH = File.join Dir.current, "eyrie.module.yml"
  LOCK_PATH = File.join Dir.current, "eyrie.lock"

  class Main < Clim
    main do
      usage "eyrie [options] <command>"
      desc "Pterodactyl Module Manager (addons and themes)"
      version "Eyrie #{::Eyrie::VERSION}"
      option "-v", "--version", type: Bool, desc: "shows the current version", default: false
      ::set_default_opts
      run do |opts, _|
        puts opts.help_string
      end

      sub "init" do
        usage "init [-f|--force]"
        desc "Initializes a module file in the current directory"
        option "-f", "--force", type: Bool, desc: "force initialize the file", default: false
        option "--lock", type: Bool, desc: "create a lockfile with the module file", default: false
        option "--skip", type: Bool, desc: "skip interactive setup", default: false
        ::set_default_opts
        run do |opts, _|
          Log.no_color if opts.no_color
          Log.trace if opts.trace

          Initializer.init_lockfile(opts.force) if opts.lock
          Initializer.init_module_file(opts.force, opts.skip, opts.lock)
        end
      end

      sub "install" do
        usage "install [-s|--source <url>] [-L|--no-lock] [-v|--verbose]"
        desc "Installs modules from a source or lockfile"
        option "-s <url>", "--source <ur>",
          type: String, desc: "the url to the module source", default: ""

        option "-t <type>", "--type <type>",
          type: String, desc: "the type of source to install from", default: "git"

        option "-v", "--verbose",
          type: Bool, desc: "output verbose and debug logs", default: false

        option "--trace",
          type: Bool, desc: "log error stack traces if present", default: false

        option "--version <v>",
          type: String, desc: "a specific version to install", default: "*"

        option "-L", "--no-lock",
          type: Bool, desc: "don't save the module in the lockfile", default: false

        ::set_default_opts
        run do |opts, _|
          Log.no_color if opts.no_color
          Log.trace if opts.trace
          Log.verbose if opts.verbose

          {% if flag?(:win32) %}
            Log.fatal "this command cannot be used on windows systems yet"
          {% end %}

          modules = [] of ModuleSpec

          if opts.source.empty?
            spec = LockSpec.from_path LOCK_PATH
            modules += spec.modules
          else
            begin
              name = opts.source.split('/').pop.downcase.underscore
              modules << ModuleSpec.new(name, opts.version, opts.source, opts.type)
            rescue ex
              Log.fatal ex
            end
          end

          Log.fatal "no modules found to install" if modules.empty?
          Installer.run modules, opts.no_lock
        end
      end
    end
  end
end

begin
  Eyrie::Main.start ARGV
rescue ex
  Eyrie::Log.trace
  Eyrie::Log.fatal ex
end

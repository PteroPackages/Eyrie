require "clim"
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
  MOD_PATH = Path[Dir.current] / "eyrie.modules.yml"
  LOCK_PATH = Path[Dir.current] / "eyrie.modules.lock"

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
        alias_name "i"
        usage "init [-f|--force]"
        desc "Initializes a module file in the current directory"
        option "-f", "--force", type: Bool, desc: "force initialize the file", default: false
        option "--lock", type: Bool, desc: "create a lockfile with the modules file", default: false
        ::set_default_opts
        run do |opts, _|
          Log.no_color if opts.no_color
          Log.trace if opts.trace
          ::Eyrie.resolve_lockfile if opts.lock

          if File.exists? MOD_PATH
            Log.fatal { "modules file already exists" } unless opts.force
            Log.fatal { "cannot write to modules file" } unless File.writable?(MOD_PATH)
          end

          begin
            File.write MOD_PATH, Module.new.to_yaml
          rescue ex
            Log.fatal(ex) { "failed to write to modules file" }
          end

          Log.info { "created modules file at:\n#{MOD_PATH}" }
        end
      end
    end
  end
end

Eyrie::Main.start ARGV

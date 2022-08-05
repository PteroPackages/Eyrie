require "clim"
require "./log"
require "./package"

macro set_default_opts
  option "--no-color", type: Bool, desc: "disable ansi color codes", default: false

  macro help_macro
    option "-h", "--help", type: Bool, desc: "sends this help message", default: false
  end
end

module Eyrie
  VERSION = "0.1.0"

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
        ::set_default_opts
        run do |opts, _|
          Log.no_color if opts.no_color
          path = Path[Dir.current].join "eyrie.modules.yml"

          if File.exists?(path)
            Log.fatal { "eyrie.modules.yml file already exists" } unless opts.force
            Log.fatal { "cannot write to eyrie.modules.yml file" } unless File.writable?(path)
          end

          begin
            File.write path, Module.new.to_yaml
          rescue ex
            Log.fatal(ex) { "failed to write to eyrie.modules.yml file" }
          end

          Log.info { "created eyrie.modules.yml file at:\n#{path}" }
        end
      end
    end
  end
end

Eyrie::Main.start ARGV

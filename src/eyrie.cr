require "clim"

module Eyrie
  VERSION = "0.1.0"

  class Main < Clim
    main do
      desc "Pterodactyl Module Manager (addons and themes)"
      usage "eyrie [options] <command>"
      version "Eyrie #{::Eyrie::VERSION}"
      option "-v", "--version", type: Bool, desc: "shows the current version", default: false
      run { }

      macro help_macro
        option "-h", "--help", type: Bool, desc: "sends this help message", default: true
      end
    end
  end
end

Eyrie::Main.start ARGV

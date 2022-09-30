module Eyrie::Commands
  class SetupCommand < CLI::Command
    def initialize(app)
      @errors = 0

      super app
    end

    def setup : Nil
      @name = "setup"
      @description = "Setup and checks Eyrie configurations and directories"
      @usage << "setup [-c|--check] [-v|--verbose] [options]"

      add_option "check", short: "c", desc: "only perform checks"
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      check_only = options.has? "check"

      check("checking main directory") do |err|
        next true if Dir.exists? "/var/eyrie"
        next false if check_only

        begin
          Dir.mkdir "/var/eyrie"

          true
        rescue ex
          err << "failed to create main directory" << '\n' << ex

          false
        end
      end

      check("checking cache directory") do |err|
        next true if Dir.exists? "/var/eyrie/cache"
        next false if check_only

        begin
          Dir.mkdir "/var/eyrie/cache"

          true
        rescue ex
          err << "failed to create cache directory" << '\n' << ex

          false
        end
      end

      check("checking save directory") do |err|
        next true if Dir.exists? "/var/eyrie/save"
        next false if check_only

        begin
          Dir.mkdir "/var/eyrie/save"

          true
        rescue ex
          err << "failed to create save directory" << '\n' << ex

          false
        end
      end

      check("checking lockfile") do |err|
        next true if File.exists? "/var/eyrie/module.lock"
        next false if check_only

        begin
          Lockfile.default.save

          true
        rescue ex
          err << "failed to create lockfile" << '\n' << ex

          false
        end
      end

      check("checking panel directory") do |err|
        next true if Dir.exists? "/var/www/pterodactyl"
        next true if Dir.exists? "/var/www/jexactyl"

        err << "could not locate panel directory" << '\n'
        err << "note that this does not check custom panel locations"

        false
      end

      Log.info "completed checks with #{@errors} error#{"s" if @errors != 1}"
    end

    private def check(info : String, & : IO -> Bool)
      Log.write info + ": "

      err = String.build do |str|
        success = yield str
        Log.info(success ? "✅" : "❌")
        @errors += 1 unless success
      end

      Log.error err.lines unless err.empty?
    end
  end
end

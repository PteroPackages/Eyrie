module Eyrie::Commands
  class ListCommand < CLI::Command
    include Base

    def setup : Nil
      @name = "list"
      @description = "Lists all installed modules and gets information on a specific module."
      add_usage "list [-n|--name <name>] [options]"

      add_option 'n', "name", desc: "the name of the module", has_value: true
      set_global_options
    end

    def run(args, options) : Nil
      Log.configure options

      lock = Lockfile.fetch
      if name = options.get("name").try &.as_s
        mod = lock.get_saved.find { |m| m.name == name }
        Log.fatal "Module '#{name}' not found or is not installed" unless mod

        mod.format STDOUT
      else
        Log.info lock.get_saved.map { |m| "#{m.name}:#{m.version}" }
      end
    end
  end
end

module Eyrie::Commands
  class ListCommand < CLI::Command
    def setup : Nil
      @name = "list"
      @description = "Lists all installed modules and gets information on a specific module."
      @usage << "list [-n|--name <name>] [options]"

      add_option "name", short: "n", desc: "the name of the module", kind: :string
      set_global_options
    end

    def execute(args, options) : Nil
      Log.configure options

      lock = Lockfile.fetch
      if name = options.get "name"
        mod = lock.get_saved.find { |m| m.name == name }
        Log.fatal "Module '#{name}' not found or is not installed" unless mod

        mod.format STDOUT
      else
        Log.info lock.get_saved.map { |m| "#{m.name}:#{m.version}" }
      end
    end
  end
end

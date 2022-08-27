module Eyrie::Commands
  class SetupCommand < CLI::Command
    def setup : Nil
      @name = "setup"
      @description = "Setup and checks Eyrie configurations and directories"
      @usage << "setup [-c|--check] [-v|--verbose] [options]"

      add_option "check-only", short: "c", desc: "only perform checks"
      add_option "verbose", short: "v", desc: "output debug and verbose logs"
      set_global_options
    end

    def execute(args, options) : Nil
      Log.no_color if options.has? "no-color"

      {% if flag?(:win32) %}
        Log.fatal "this command cannot be used on windows systems yet"
      {% end %}

      Log.trace if options.has? "trace"
      Log.verbose if options.has? "verbose"

      nocheck = options.has? "check-only"
      errors = 0i8
      warns = 0i8

      STDOUT << "checking main directory:  "
      if Dir.exists? "/var/eyrie"
        Log.info "✅"
      else
        Log.info "❌"
        Log.vwarn "main directory '/var/eyrie' not found"
        Log.vinfo "creating main directory"
        warns += 1

        unless nocheck
          begin
            Dir.mkdir "/var/eyrie"
          rescue ex
            Log.error ex, "failed to create main directory"
            errors += 1
          end
        end
      end

      STDOUT << "checking cache directory: "
      if Dir.exists? "/var/eyrie/cache"
        Log.info "✅"

        unless nocheck && Dir.empty? "/var/eyrie/cache"
          STDOUT << "clearing cache directory: "
          begin
            Util.rm_rf "/var/eyrie/cache/*"
            Log.info "✅"
          rescue ex
            Log.info "❌"
            Log.error ex, "failed to clear cache directory"
            errors += 1
          end
        end
      else
        Log.info "❌"
        Log.vwarn "cache directory '/var/eyrie/cache' not found"
        warns += 1

        unless nocheck
          STDOUT << "creating cache directory: "
          begin
            Dir.mkdir "/var/eyrie/cache"
            Log.info "✅"
          rescue ex
            Log.info "❌"
            Log.error ex, "failed to create cache dircetory"
            errors += 1
          end
        end
      end

      STDOUT << "checking save directory:  "
      if Dir.exists? "/var/eyrie/save"
        Log.info "✅"

        files = Dir.glob("/var/eyrie/save")
          .reject { |f| f.starts_with?('.') || f.ends_with?(".save.yml") }

        unless files.empty?
          if nocheck
            Log.vwarn "save directory contains unrelated files"
          else
            STDOUT << "clearing cache directory: "
            begin
              Util.rm_rf "/var/eyrie/cache/*"
              Log.info "✅"
            rescue ex
              Log.info "❌"
              Log.error ex, "failed to clear cache directory"
              errors += 1
            end
          end
        end
      else
        Log.info "❌"
        Log.vwarn "save directory '/var/eyrie/save' not found"
        warns += 1

        unless nocheck
          Log.vinfo "creating save directory"
          begin
            Dir.mkdir "/var/eyrie/save"
          rescue ex
            Log.error ex, "failed to create save directory"
            errors += 1
          end
        end
      end

      STDOUT << "checking panel directory: "
      if Dir.exists? "/var/www/pterodactyl"
        Log.info "✅"
      else
        Log.info "❌"
        Log.error [
          "panel directory not found",
          "if it is in a different location, please specify the --root flag",
          "with the new location"
        ]
        errors += 1
      end

      Log.info "\ncompleted checks with #{errors} error#{"s" if errors != 1} \
        and #{warns} warning#{"s" if warns != 1}"

      if !warns.zero? && !options.has? "verbose"
        Log.info "run with the --verbose flag for details"
      end
      Log.info "run with the --no-check flag to skip warn/error fixes" unless nocheck
    end
  end
end

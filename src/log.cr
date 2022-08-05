require "colorize"

Colorize.on_tty_only!

module Eyrie
  class Log
    @@trace = false
    @@verbose = false
    @@warn = true

    def self.no_color : Nil
      Colorize.enabled = false
    end

    def self.trace : Nil
      @@trace = true
    end

    def self.no_warnings : Nil
      @@warn = false
    end

    def self.verbose : Nil
      @@verbose = true
    end

    def self.info(& : -> String)
      STDOUT.puts yield
    end

    def self.vinfo(& : -> String)
      STDOUT.puts yield if @@verbose
    end

    def self.warn(& : -> String)
      if @@warn
        STDOUT.puts "warning".colorize(:yellow).to_s + ": " + yield
      end
    end

    def self.error(& : -> String)
      STDERR.puts "error".colorize(:red).to_s + ": " + yield
    end

    def self.error(ex : Exception, & : ->)
      res = yield
      error { res || ex.message || "an unknown error occured" }
      if @@trace
        error { ex.message || "" } if res
        ex.backtrace.each { |l| error { l } }
      end
    end

    def self.fatal(& : -> String)
      error { yield }
      exit 1
    end

    def self.fatal(ex : Exception, & : ->)
      error(ex) { yield }
      exit 1
    end
  end
end

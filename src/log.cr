require "colorize"

module Eyrie
  class Log
    @@trace = false
    @@verbose = false
    @@warn = true

    def self.no_color : Nil
      Colorize.on_tty_only!
    end

    def self.trace : Nil
      @@tace = true
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
        STDOUT.puts "warning".colorize(:yellow) + ": " + yield
      end
    end

    def self.error(& : -> String)
      STDERR.puts "error".colorize(:red) + ": " + yield
    end

    def self.error(ex : Exception, & : ->)
      res = yield
      error { res || ex.message }
      if @@trace
        ex.stack_trace.lines.each { |l| error { l } }
      end
    end
  end
end

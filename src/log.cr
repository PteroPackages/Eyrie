require "colorize"

Colorize.on_tty_only!

module Eyrie::Log
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

  def self.info(args : String)
    STDOUT.puts args
  end

  def self.info(args : Array(String))
    STDOUT.puts args.join('\n')
  end

  def self.vinfo(args : String)
    STDOUT.puts args if @@verbose
  end

  def self.vinfo(args : Array(String))
    info args if @@verbose
  end

  def self.warn(args : String)
    return unless @@warn
    STDOUT.puts "warn".colorize(:yellow).to_s + ": #{args}"
  end

  def self.warn(args : Array(String))
    args.each { |a| warn a }
  end

  def self.warn(ex : Exception, args : String | Array(String))
    warn args
    warn "source: " + ex.message.to_s
    ex.backtrace.each { |t| warn t } if @@trace
  end

  def self.vwarn(args : String | Array(String))
    warn args if @@verbose
  end

  def self.error(args : String)
    STDERR.puts "error".colorize(:red).to_s + ": #{args}"
  end

  def self.error(args : Array(String))
    args.each { |a| error a }
  end

  def self.error(ex : Exception)
    error ex.message || "an unknown error occured"
    ex.backtrace.each { |t| error t } if @@trace
  end

  def self.error(ex : Exception, args : String | Array(String))
    error args
    error ex.message.not_nil! if ex.message
    ex.backtrace.each { |t| error t } if @@trace
  end

  def self.fatal(args : String | Array(String) | Exception)
    error args
    exit 1
  end

  def self.fatal(ex : Exception, args : String | Array(String))
    error ex, args
    exit 1
  end
end

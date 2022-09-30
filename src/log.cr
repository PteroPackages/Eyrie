module Eyrie::Log
  extend self

  @@trace = false
  @@verbose = false

  def configure(options : CLI::OptionsInput) : Nil
    Colorize.enabled = false if options.has? "no-color"
    @@trace = true if options.has? "trace"
    @@verbose = true if options.has? "verbose"
  end

  def write(args : String) : Nil
    STDOUT << args
  end

  def info(args : String) : Nil
    STDOUT.puts args
  end

  def info(args : Array(String)) : Nil
    STDOUT.puts args.join '\n'
  end

  def vinfo(args : _) : Nil
    info args if @@verbose
  end

  def warn(args : String) : Nil
    STDOUT.puts %(#{"warn".colorize(:yellow)}: #{args})
  end

  def warn(args : Array(String)) : Nil
    args.each { |a| warn a }
  end

  def warn(ex : Exception, args : _) : Nil
    warn args
    warn "source: " + ex.message.to_s
    ex.backtrace.each { |t| warn t } if @@trace
  end

  def vwarn(args : _) : Nil
    warn args if @@verbose
  end

  def vwarn(ex : Exception) : Nil
    return unless @@verbose
    warn ex.message || "an unknown error occured"
    ex.backtrace.each { |t| warn t } if @@trace
  end

  def error(args : String) : Nil
    STDERR.puts %(#{"error".colorize(:red)}: #{args})
  end

  def error(args : Array(String)) : Nil
    args.each { |a| error a }
  end

  def error(ex : Exception) : Nil
    error ex.message || "an unknown error occured"
    ex.backtrace.each { |t| error t } if @@trace
  end

  def error(ex : Exception, args : _) : Nil
    error args
    error ex.message.not_nil! if ex.message
    ex.backtrace.each { |t| error t } if @@trace
  end

  def fatal(args : _) : Nil
    error args
    raise SystemExit.new
  end

  def fatal(ex : Exception, args : _) : Nil
    error ex, args
    raise SystemExit.new
  end
end

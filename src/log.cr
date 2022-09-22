module Eyrie::Log
  extend self

  enum Status
    INVALID_NAME
    INVALID_VERSION
    INVALID_SUPPORTS
    NO_FILES
  end

  @@trace = false
  @@verbose = false
  @@warn = true

  def configure(options : CLI::OptionsInput) : Nil
    Colorize.enabled = false if options.has? "no-color"
    @@trace = true if options.has? "trace"
    @@verbose = true if options.has? "verbose"
    # @@warn = false if options.has? "no-warn"
  end

  def get_message(status : Status) : Array(String)
    case status
    in Status::INVALID_NAME
      ["module name is invalid", "module name can only contain letters, numbers, dashes and underscores"]
    in Status::INVALID_VERSION
      ["invalid version format", "module versions must be in the major.minor.patch format"]
    in Status::INVALID_SUPPORTS
      ["invalid supported version", "supported version must be in the major.minor.patch format"]
    in Status::NO_FILES
      ["no files were specified to install with the module", "cannot guess which files to install"]
    end
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
    return unless @@warn
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
    return unless @@verbose && @@warn
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
    exit 1
  end

  def fatal(ex : Exception, args : _) : Nil
    error ex, args
    exit 1
  end
end

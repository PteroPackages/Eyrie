module Eyrie
  class Version
    getter major : Int32
    getter minor : Int32
    getter patch : Int32

    def initialize(@major, @minor, @patch)
    end

    def self.parse(format : String)
      raise Error.new(:invalid_version) unless format =~ /^(\*$|\d+)(?:\.(\d+))?(?:\.(\d+))?(?:[\w.-]+)?$/
      return new(-1, -1, -1) if $1 == "*"

      major = $1.to_i
      raise "invalid major version (less than 0)" if major < 0

      minor = -1
      if m = $2?.try &.to_i
        raise "invalid minor version (less than 0)" if m < 0
        minor = m
      end

      patch = -1
      if p = $3?.try &.to_i
        raise "invalid patch version (less than 0)" if p < 0
        patch = p
      end

      new major, minor, patch
    end

    def to_s(io : IO) : Nil
      if @major == -1
        io << '*'
        return
      else
        io << @major
      end

      unless @minor == -1
        io << '.' << @minor
      end

      unless @patch == -1
        io << '.' << @patch
      end
    end

    def <=>(other : Version) : Int
      return 0 if @major == -1

      i = @major <=> other.major
      return i unless i.zero?

      i = @minor <=> other.minor
      return i unless i.zero?

      @patch <=> other.patch
    end
  end
end

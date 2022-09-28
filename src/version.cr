module Eyrie
  class Version
    getter major : Int32
    getter minor : Int32
    getter patch : Int32

    def_equals @major, @minor, @patch

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

      io << '.'
      if @minor == -1
        io << 'x'
        return
      else
        io << @minor
      end

      io << '.'
      if @patch == -1
        io << 'x'
        return
      else
        io << @patch
      end
    end

    def accepts?(other : Version) : Bool
      major = @major == -1 ? other.major : @major
      minor = @minor == -1 ? other.minor : @minor
      patch = @patch == -1 ? other.patch : @patch

      return true if Version.new(major, minor, patch) == other

      (major == -1 || major > other.major) && (minor == -1 || minor > other.minor) && (patch == -1 || patch > other.patch)
    end
  end
end

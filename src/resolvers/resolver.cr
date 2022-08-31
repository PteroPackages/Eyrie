module Eyrie
  abstract class Resolver
    def self.exec(command : String) : Exception?
      Log.vinfo command
      err = IO::Memory.new

      Process.run command, shell: true, error: err
      if err.to_s.includes? "fatal"
        raise err.to_s.lines.last
      end
    rescue ex
      ex
    end
  end
end

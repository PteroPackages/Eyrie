module Eyrie
  abstract class Resolver
    def self.exec(command : String) : Exception?
      Log.vinfo command
      Process.run command, shell: true
      raise "command failed: #{$?.exit_code}" unless $?.success?
    rescue ex
      ex
    end
  end
end

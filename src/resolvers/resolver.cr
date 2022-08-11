require "../package"

module Eyrie
  abstract class Resolver
    def self.exec(command : String) : Exception?
      Log.vinfo { command }
      Process.exec command, shell: true, chdir: "/var/eyrie/cache"
    rescue ex
      ex
    end
  end
end

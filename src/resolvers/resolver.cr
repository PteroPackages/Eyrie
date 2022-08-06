require "../package"

module Eyrie
  abstract class Resolver
    def self.cache_path : Path
      {% if flag?(:win32) %}
        Path[ENV["APPDATA"]].join "eyrie", "cache"
      {% else %}
        Path["/var/eyrie/cache"]
      {% end %}
    end

    def self.run(mod : ModuleSpec) : Bool
      false
    end

    def self.rewrite(path : Path) : Bool
      if File.exists? path
        begin
          Dir.delete path
        rescue # TODO: log in warn
          Log.warn { "could not remove cached module" }
          return true
        end
      end

      begin
        Dir.mkdir path
      rescue ex
        Log.error(ex) { "failed to set cache for module" }
        return false
      end

      true
    end

    def self.exec(cmd : String) : Bool
      Process.run cmd, shell: true
      true
    rescue
      false
    end

    def self.exec_in_cache(cmd : String) : Bool
      Process.run cmd, shell: true, chdir: cache_path.to_s
      true
    rescue
      false
    end
  end
end
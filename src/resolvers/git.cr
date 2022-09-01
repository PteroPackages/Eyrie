require "./resolver"

module Eyrie
  class GitResolver < Resolver
    def self.run(spec : ModuleSpec) : Bool
      cache = File.join "/var/eyrie/cache", spec.name
      count = 0

      spec.validate

      loop do
        Log.vinfo "cloning: #{spec.source.uri}"
        if ex = exec "git clone -c core.askPass=true #{spec.source.uri} #{cache}"
          Log.error ex, "failed to clone repository"
          break if count == 0
          count += 1
          Log.vinfo "retrying (attempt #{count + 1})"
        end

        return true
      end

      false
    end
  end
end

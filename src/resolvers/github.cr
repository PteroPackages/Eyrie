require "./resolver"

module Eyrie
  class GithubResolver < Resolver
    def self.run(mod : ModuleSpec) : Bool
      path = cache_path / mod.name
      return false unless rewrite path

      done = false
      3.times do
        next if done
        Log.vinfo { "cloning: #{mod.source.url}" }
        done = exec "git clone -c core.askPass=true #{mod.source.url} #{path}"
      end

      Log.error { "failed to clone repository for '#{mod.name}'" } unless done
      done
    end
  end
end

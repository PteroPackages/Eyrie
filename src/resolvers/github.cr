require "./resolver"

module Eyrie
  class GithubResolver < Resolver
    def self.run(mod : ModuleSpec) : Bool
      path = cache_path / mod.name
      return false unless rewrite path

      done = false
      3.times do
        next if done
        Log.vinfo { "attempting clone: #{mod.source.url}" }
        done = exec_in_cache "git clone -c core.askPass=true #{mod.source.url} ."
      end

      Log.error { "failed to clone repository for '#{mod.name}'" } unless done
      done
    end
  end
end

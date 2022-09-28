module Eyrie::Resolver
  def self.pull_from_local(mod : Module) : Nil
    # check if directory exists or if forward eyrie.yml exists
    # resolve files and move to cache
  end

  def self.pull_from_git(mod : Module) : Nil
    cache = File.join "/var/eyrie/cache", mod.name

    if ex = exec "git clone -c core.askPass=true #{mod.source.not_nil!.uri} #{cache}"
      raise Error.new ex, :pull_git_failed
    end
  end

  private def self.exec(command : String) : Exception?
    Log.vinfo command
    err = IO::Memory.new
    Process.run command, shell: true, error: err
    if (msg = err.to_s).includes? "fatal"
      Exception.new msg.lines.last
    end
  rescue ex
    ex
  end
end

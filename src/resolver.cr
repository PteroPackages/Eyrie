module Eyrie::Resolver
  def self.pull_from_local(mod : Module) : Nil
    # check if directory exists or if forward eyrie.yml exists
    # resolve files and move to cache
  end

  def self.pull_from_git(mod : Module) : Nil
    cache = File.join "/var/eyrie/cache", mod.name

    loop do |i|
      if ex = exec "git clone -c core.askPass=true #{mod.source.not_nil!.uri} #{cache}"
        raise ex if i == 2
        Log.error ex, "failed to clone git repository"
        Log.vinfo "retrying..."
      end
    end
  end

  private def self.exec(command : String) : Exception?
    Log.vinfo command
    err = IO::Memory.new
    Process.run command, shell: true, error: err
    unless (msg = err.to_s).empty?
      Exception.new msg.lines.last
    end
  rescue ex
    ex
  end
end

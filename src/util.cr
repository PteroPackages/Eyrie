module Eyrie::Util
  def self.run_prerequisites : Nil
    Log.vinfo "checking panel availability"
    Log.vinfo "checking cache availability"

    unless Dir.exists? "/var/eyrie/cache"
      Log.vwarn "cache directory not found, attempting to create"
      begin
        Dir.mkdir_p "/var/eyrie/cache"
      rescue ex
        Log.fatal ex, "failed to create cache directory"
      end
    end

    unless Dir.empty? "/var/eyrie/cache"
      Log.vinfo "cache directory not empty, attempting clean"
      begin
        self.rm_rf "/var/eyrie/cache/*"
        raise "cache directory is not empty" unless Dir.empty? "/var/eyrie/cache"
      rescue ex
        Log.warn ex, "failed to clean cache directory"
      end
    end

    Log.vinfo "checking save availability"
    unless Dir.exists? "/var/eyrie/save"
      Log.vwarn "save directory not found, attempting to create"
      begin
        Dir.mkdir_p "/var/eyrie/save"
      rescue ex
        Log.fatal ex, "failed to create save directory"
      end
    end

    Log.vinfo "checking git availability"
    begin
      `git --version`
    rescue ex
      Log.fatal ex, "git is required for this operation"
    end
  end

  private def self.rm_r(path : String) : Nil
    if Dir.exists?(path) && !File.symlink?(path)
      Dir.each_child(path) do |entry|
        src = File.join path, entry
        rm_r src
      end
      Dir.delete path
    else
      File.delete path
    end
  end

  def self.rm_rf(path : String) : Nil
    if path.includes? '*'
      Dir.glob(path) { |p| rm_r p }
    else
      rm_r path
    end
  rescue
  end

  # def self.each_in_mapping(yaml : YAML::PullParser, &) : Nil
  #   until yaml.kind == YAML::EventKind::MAPPING_END
  #     yield
  #   end
  #   yaml.read_mapping_end
  # end
end

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
        FileUtils.rm_rf "/var/eyrie/cache/"
      rescue ex
        Log.warn ex, "failed to clean cache path"
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
end

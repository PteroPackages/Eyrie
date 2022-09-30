module Eyrie::Util
  extend self

  def run_system_checks : Nil
    unless Dir.exists? "/var/eyrie/cache"
      Log.vinfo "cache directory not found, attempting to create"
      begin
        Dir.mkdir_p "/var/eyrie/cache"
      rescue ex
        Log.fatal ex, "failed to create cache directory"
      end
    end

    clear_cache_dir

    unless Dir.exists? "/var/eyrie/save"
      Log.vinfo "save directory not found, attempting to create"
      begin
        Dir.mkdir_p "/var/eyrie/save"
      rescue ex
        Log.fatal ex, "failed to creat cache directory"
      end
    end
  end

  def get_panel_path(path : String) : String
    if path.empty?
      if Dir.exists? "/var/www/pterodactyl"
        path = "/var/www/pterodactyl/"
      elsif Dir.exists? "/var/www/jexactyl"
        path = "/var/www/jexactyl/"
      end
    else
      Log.fatal "could not locate panel path" unless Dir.exists? path
    end

    path + (path.ends_with?('/') ? "" : '/')
  end

  def get_panel_version(path : String) : SemanticVersion
    path = File.join(path, "config", "app.php")
    Log.fatal [
      "could not find the panel config file",
      "make sure you have installed your panel correctly then retry"
    ] unless File.exists? path

    data = File.read path
    data =~ /'version' => '(.*)'/
    Log.fatal [
      "could not get panel version from the config",
      "please ensure a valid panel version is set in your config"
    ] unless $1?

    Log.fatal [
      "canary builds of the panel are not supported",
      "please install an official version of the panel to use this application"
    ] if $1 == "canary"

    begin
      SemanticVersion.parse $1
    rescue
      Log.fatal "panel version is invalid (must follow semver spec)"
    end
  end

  def clear_cache_dir : Nil
    rm_rf "/var/eyrie/cache/*"
  end

  private def rm_r(path : String) : Nil
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

  def rm_rf(path : String) : Nil
    if path.includes? '*'
      Dir.glob(path) { |p| rm_r p }
    else
      rm_r path
    end
  rescue
  end

  def rm_rf(paths : Array(String)) : Nil
    paths.each { |p| rm_r p }
  end

  def copy(srcs : Array(String), dest : String) : Nil
    srcs.each do |src|
      if File.directory? src
        Dir.mkdir_p File.join(dest, src)
      else
        File.copy src, File.join(dest, src)
      end
    end
  end
end

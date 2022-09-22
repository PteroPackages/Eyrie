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
        path = "/var/www/pterodactyl"
      elsif Dir.exists? "/var/www/jexactyl"
        path = "/var/www/jexactyl"
      end
    else
      Log.fatal "could not locate panel path" unless Dir.exists? root
    end

    Log.fatal "could not locate panel path" if path.empty?

    path
  end

  def get_panel_version(path : String) : String
    path = File.join path, "config", "app.php"
    Log.fatal [
      "panel 'app.php' config file not found",
      "this file is required for installing modules"
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

    $1
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

  def parse_version(value : String) : SemanticVersion
    return SemanticVersion.new(0, 0, 0) if value == "*"

    value =~ %r[\d+(\.\d+)?(\.\d+)?]
    value += ".0" unless $1?
    value += ".0" unless $2?

    SemanticVersion.parse value
  end
end

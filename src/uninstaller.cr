module Eyrie::Uninstaller
  def self.run(mod : Module) : Nil
    Log.warn [
      "uninstalling a module is not a secure process",
      "make sure to replace any overriden module files with the panel's default files",
      "or run the panel upgrade command after this"
    ]

    taken = Time.measure do
      Log.vinfo "validating module"
      begin
        mod.validate
      rescue ex
        Log.fatal ex, "failed to validate module '#{mod.name}'"
      end

      remove_files mod.files
      cleanup_cache mod.name
    end

    Log.info "uninstalled module '#{mod.name}' in #{taken.milliseconds}ms"
  end

  private def self.remove_files(files : Files) : Nil
    Dir.cd("/var/www/pterodactyl") do
      includes = Dir.glob files.include
      excludes = Dir.glob files.exclude
      includes.reject! &.in? excludes

      return Log.error "no module files found to remove" if includes.empty?

      Log.vinfo "removing module files"
      includes.each do |path|
        Log.vinfo "path: " + path
        begin
          File.delete path
        rescue ex
          Log.vwarn ex
        end
      end
    end
  end

  private def self.cleanup_cache(name : String) : Nil
    path = File.join "/var/eyrie/save", name + ".save.yml"

    if File.exists? path
      Log.vinfo "removing module save file"
      begin
        File.delete path
      rescue ex
        Log.warn ex, [
          "failed to remove module save file",
          "the module will continue to show as installed unless this file is removed"
        ]
      end
    end

    unless Dir.empty? "/var/eyrie/cache"
      begin
        FileUtils.rm_rf "/var/eyrie/cache/"
      rescue ex
        Log.warn ex, "failed to clean cache directory"
      end
    end
  end
end

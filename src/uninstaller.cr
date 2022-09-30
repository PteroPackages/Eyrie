module Eyrie::Uninstaller
  def self.run(mod : Module, root : String) : Nil
    Log.warn [
      "Uninstalling a module is not a secure process",
      "Make sure to replace any overriden module files with the panel's default files",
      "or run the panel upgrade command after this"
    ]

    Dir.cd(root) do
      Log.vinfo "collecting included and excluded files"

      parts, includes = mod.files.includes.partition &.includes? '*'
      includes += parts.flat_map { |p| Dir.glob(p) } unless parts.empty?

      parts, excludes = mod.files.excludes.partition &.includes? '*'
      includes += parts.flat_map { |p| Dir.glob(p) } unless parts.empty?

      includes.reject! &.in? excludes
      includes.reject! { |p| Dir.exists?(p) }
      return Log.warn "No module files found to remove" if includes.empty?

      Log.info "Removing module files from panel..."
      Log.vinfo [
        "included #{includes.size} files, excluded #{excludes.size} files",
        "source: #{root}"
      ]

      begin
        Util.rm_rf includes
      rescue ex
        Log.error ex, "Failed to remove module files from panel"
      end
    end
  end
end

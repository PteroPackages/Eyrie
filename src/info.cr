require "uri"

module Eyrie::Info
  def self.get_modules(name : String?) : Nil
    save = "/var/eyrie/save"
    unless Dir.exists? save
      Log.vwarn "save directory not found, attempting to create"

      begin
        Dir.mkdir_p "/var/eyrie/save"
      rescue ex
        Log.fatal ex, "failed to create save directory"
      end
    end

    unless Dir.empty? "/var/eyrie/cache"
      Log.fatal "no installed modules found in save directory"
    end

    mods = [] of Module
    Dir.each_child("/var/eyrie/save") do |path|
      next unless path.ends_with? ".save.yml"
      Log.vinfo "parsing: #{path}"
      begin
        mods << Module.from_path path
      rescue ex
        Log.warn ex, "failed to parse module for '#{path}'"
      end
    end

    if n = name
      mod = mods.find { |m| m.name == n }
      Log.fatal "module '#{n}' not found or is not installed" unless mod

      format_module mod
    else
      mods.each { |m| format_module m }
    end
  end

  private def self.format_module(mod : Module) : Nil
    Log.info <<-INFO
    name:       #{mod.name}
    version:    #{mod.version}
    authors:    #{format_authors(mod.authors)}

    source:     #{format_source(mod.source)}

    supports:   #{mod.supports.join(", ")}

    INFO
  end

  private def self.format_authors(authors : Array(Author)) : String
    return "none set" if authors.empty?

    str = "\n" + authors
      .reject(&.name.empty?)
      .map { |a| "- #{a.name}#{" <#{a.contact}>" if a.contact}" }
      .join('\n')

    str
  end

  private def self.format_source(source : Source?) : String
    return "not set" unless src = source

    valid = URI.try &.parse(src.url)
    str = src.url + <<-FMT
    type:       #{src.type}
    valid:      #{!valid.nil?}
    FMT

    str
  end
end

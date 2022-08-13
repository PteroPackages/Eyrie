require "uri"

module Eyrie::List
  def self.get_module_info(name : String) : Nil
    save = "/var/eyrie/save"
    unless Dir.exists? save
      Log.vwarn "save directory not found, attempting to create"

      begin
        Dir.mkdir_p "/var/eyrie/save"
      rescue ex
        Log.fatal ex, "failed to create save directory"
      end
    end

    mod = get_modules.find { |m| m.name == name }
    Log.fatal "module '#{name}' not found or is not installed" unless mod

    format_module mod
  end

  def self.list_modules : Nil
    puts get_modules.map { |m| m.name + ":" + m.version }.join('\n')
  end

  def self.get_modules : Array(Module)
    if Dir.empty? "/var/eyrie/save"
      Log.fatal "no installed modules found in save directory"
    end

    mods = [] of Module

    Dir.each_child("/var/eyrie/save") do |path|
      next unless path.ends_with? ".save.yml"
      Log.vinfo "parsing: #{path}"

      begin
        mods << Module.from_path "/var/eyrie/save/" + path
      rescue ex
        Log.warn ex, "failed to parse module for '#{path}'"
      end
    end

    mods
  end

  private def self.format_module(mod : Module) : Nil
    Log.info <<-INFO
    name:       #{mod.name}
    version:    #{mod.version}
    authors:    #{format_authors(mod.authors)}

    source:     #{format_source(mod.source)}

    supports:   #{mod.supports}

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

    src.validate
    valid = URI.try &.parse(src.url)
    str = src.url.ends_with?(".git") ? src.url[...-4] : src.url
    str += <<-FMT

    type:       #{src.type}
    valid:      #{!valid.nil?}
    FMT

    str
  end
end

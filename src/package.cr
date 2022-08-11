require "semantic_version"
require "yaml"

module Eyrie
  struct Author
    include YAML::Serializable

    property name     : String
    property contact  : String

    def initialize(@name, @contact); end
  end

  enum SourceType
    Local
    Git
    Github
    Gitlab
  end

  struct Source
    include YAML::Serializable

    property url  : String
    property type : SourceType

    def initialize(@url, @type = :git); end

    def validate : Nil
      {% for src in %w(github gitlab) %}
        if @type.{{ src.id }}? && !@url.starts_with?("https://{{ src.id }}.com")
          @url = "https://{{ src.id }}.com/#{@url}"
        end
      {% end %}
    end
  end

  struct CmdDepSpec
    include YAML::Serializable

    property composer : Hash(String, String)
    property npm      : Hash(String, String)

    def initialize
      @composer = {} of String => String
      @npm = {} of String => String
    end
  end

  struct Deps
    include YAML::Serializable

    property install  : CmdDepSpec?
    property remove   : CmdDepSpec?

    def initialize
      @install = CmdDepSpec.new
      @remove = CmdDepSpec.new
    end
  end

  struct Files
    include YAML::Serializable

    property include  : Array(String)
    property exclude  : Array(String)
    # property mappings : Hash(String, String)
    property remove   : Array(String)

    def initialize
      @include = [] of String
      @exclude = [] of String
      @remove = [] of String
    end
  end

  struct Module
    include YAML::Serializable

    property name       : String
    property version    : String
    property authors    : Array(Author)
    property source     : Source?
    property supports   : Array(String)
    property deps       : Deps
    property files      : Files
    property postinstall : Array(String)

    def initialize
      @name = "module-name"
      @version = "0.0.1"
      @authors = [Author.new("your-name-here", "your@contact.here")]
      @source = Source.new "url-to-source"
      @supports = [] of String
      @deps = Deps.new
      @files = Files.new
      @postinstall = [] of String
    end

    def self.from_file(path : String)
      data = File.read path
      from_yaml data
    end

    def validate : Nil
      if @name =~ %r[[^a-z0-9_-]]
        raise "name can only contain lowercase letters, numbers, dashes, and underscores"
      end

      begin
        SemanticVersion.parse @version
      rescue ex
        raise Exception.new "invalid version format '#{@version}'", cause: ex
      end

      raise "no supported panel versions set" if @supports.empty?

      if @files.include.empty?
        raise "no files included, cannot assume files to install"
      end
    end

    def to_spec : ModuleSpec
      ModuleSpec.new @name, @version, @source || Source.new("", :local)
    end
  end

  struct ModuleSpec
    include YAML::Serializable

    property name     : String
    property version  : String
    property source   : Source

    def initialize(@name, @version, @source); end

    def initialize(@name, @version, url, type)
      t = case type
          when "local"
            SourceType::Local
          when "git"
            SourceType::Git
          when "github"
            SourceType::Github
          else
            raise "invalid source type '#{type}'"
          end

      @source = Source.new url, t
    end

    def validate : Nil
      if @name =~ %r[[^a-z0-9_-]]
        raise "name can only contain lowercase letters, numbers, dashes, and underscores"
      end

      unless @version == "*"
        begin
          SemanticVersion.parse @version
        rescue ex
          raise Exception.new "invalid version format '#{@version}'", cause: ex
        end
      end

      @source.validate
    end
  end

  struct LockSpec
    include YAML::Serializable

    @[YAML::Field(key: "lock_version")]
    property version : Int32
    property modules : Array(ModuleSpec)

    def initialize
      @version = LOCK_VERSION
      @modules = [] of ModuleSpec
    end
  end

  def self.resolve_lockfile : LockSpec
    if File.exists? LOCK_PATH
      begin
        data = File.read LOCK_PATH
        LockSpec.from_yaml data
      rescue ex
        Log.fatal(ex) { "failed to read lockfile" }
      end
    else
      begin
        spec = LockSpec.new
        File.write LOCK_PATH, spec.to_yaml
        spec
      rescue ex
        Log.fatal(ex) { "failed to write lockfile" }
      end
    end
  end
end

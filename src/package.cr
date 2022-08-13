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

      @url += ".git" unless @type.local? && @url.ends_with?(".git")
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
    property exclude  : Array(String) = [] of String
    property mappings : Hash(String, String) = {} of String => String
    property remove   : Array(String) = [] of String

    def initialize
      @include = [] of String
      @exclude = [] of String
      @mappings = {} of String => String
      @remove = [] of String
    end
  end

  struct Module
    include YAML::Serializable

    property name       : String
    property version    : String
    property authors    : Array(Author) = [] of Author
    property source     : Source?
    property supports   : String
    @[YAML::Field(key: "dependencies")]
    property deps       : Deps = Deps.new
    property files      : Files
    property postinstall : Array(String) = [] of String

    def initialize
      @name = "module-name"
      @version = "0.0.1"
      @authors = [Author.new("your-name-here", "your@contact.here")]
      @source = Source.new "url-to-source"
      @supports = ""
      @files = Files.new
      @postinstall = [] of String
    end

    def self.from_path(path : String)
      data = File.read path
      from_yaml data
    end

    def validate : Nil
      if @name.matches? /[^a-z0-9_-]/
        raise "name can only contain lowercase letters, numbers, dashes, and underscores"
      end

      begin
        SemanticVersion.parse @version
      rescue ex
        raise Exception.new "invalid version format '#{@version}'", cause: ex
      end

      unless @supports.matches? /[*~<|>=^]*\d+\.\d+\.\d+[*~<|>=^]*/
        raise "invalid supported version requirement"
      end

      if @files.include.empty?
        raise "no files included, cannot assume files to install"
      end

      @source.try &.validate
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
      if @name.matches? /[^a-z0-9_-]/
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

    def self.from_path(path : String)
      data = File.read path
      from_yaml data
    end
  end
end

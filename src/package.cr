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
    # Gitlab
  end

  struct Source
    include YAML::Serializable

    property url  : String
    property type : SourceType

    def initialize(@url, @type = :git); end
  end

  struct Deps
    include YAML::Serializable

    property install  : Hash(String, String)
    property remove   : Hash(String, String)

    def initialize
      @install = {} of String => String
      @remove = {} of String => String
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

    property name     : String
    property version  : String
    property authors  : Array(Author)
    property source   : Source
    property supports : Array(String)
    property deps     : Deps
    property files    : Files

    def initialize
      @name = "module-name"
      @version = "0.0.1"
      @authors = [Author.new("your-name-here", "your@contact.here")]
      @source = Source.new "url-to-source"
      @supports = [] of String
      @deps = Deps.new
      @files = Files.new
    end
  end

  struct ModuleSpec
    include YAML::Serializable

    property name     : String
    property version  : String
    property source   : Source
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

module Eyrie
  struct ModuleSpec
    property name : String
    property version : String
    property source : Source

    def initialize(@name, @version, @source); end

    def initialize(@name, @version, url, type)
      @source = Source.new url, type
    end

    def self.new(data : YAML::Any)
      raise "missing name field for lockfile" unless data["name"]?
      raise "missing version field for lockfile" unless data["version"]?
      raise "missing source field for lockfile" unless data["source"]?

      name = data["name"].as_s
      version = data["version"].as_s
      source = Source.new data["source"]

      new name, version, source
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

    def to_yaml(yaml : YAML::Builder) : Nil
      yaml.scalar "name"
      yaml.scalar @name
      yaml.scalar "version"
      yaml.scalar @version

      yaml.scalar "source"
      yaml.mapping do
        yaml.scalar "url"
        yaml.scalar @source.url
        yaml.scalar "type"
        yaml.scalar @source.type
      end
    end
  end

  struct LockSpec
    property version : Int32
    property modules : Array(ModuleSpec)

    def initialize(@version, @modules); end

    def self.new(data : YAML::Any)
      raise "missing version field for lockfile" unless data["lock_version"]?
      raise "missing modules field for lockfile" unless data["modules"]?

      version = data["lock_version"].as_i
      raise "invalid version for lockfile" unless version == LOCK_VERSION
      modules = data["modules"].as_a.map { |m| ModuleSpec.new m }

      new version, modules
    end

    def self.from_path(path : String)
      raise "lockfile path does not exist: #{path}" unless File.exists? path
      data = YAML.parse File.read(path)
      new data
    end

    def self.default
      new LOCK_VERSION, [] of ModuleSpec
    end

    def to_yaml : String
      YAML.build do |yaml|
        yaml.scalar "lock_version"
        yaml.scalar @version

        yaml.scalar "modules"
        yaml.sequence do
          @modules.each do |spec|
            yaml.mapping do
              spec.to_yaml yaml
            end
          end
        end
      end
    end
  end
end

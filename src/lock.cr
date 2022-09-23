module Eyrie
  class ModuleSpec
    getter name : String
    getter version : String
    getter source : Source

    def initialize(@name, @version, @source)
    end

    def self.new(data : YAML::Any)
      raise "missing name for module spec" unless data["name"]?
      raise "missing version for module spec" unless data["version"]?
      raise "missing source info for module spec" unless data["source"]?

      source = Source.new data["source"]
      new data["name"].as_s, data["version"].as_s, source
    end

    def validate : Nil
      raise Error.new(:invalid_name) if @name.matches? /[^a-z0-9_-]+/

      unless @version == "*"
        begin
          SemanticVersion.parse @version
        rescue
          raise Error.new(:invalid_version)
        end
      end
    end

    def format(io : IO) : Nil
    end

    def to_yaml(yaml : YAML::Builder) : Nil
      yaml.scalar "name"
      yaml.scalar @name
      yaml.scalar "version"
      yaml.scalar @version

      yaml.scalar "source"
      yaml.mapping do
        yaml.scalar "uri"
        yaml.scalar @source.uri
        yaml.scalar "type"
        yaml.scalar @source.type
      end
    end
  end

  class Lockfile
    VERSIONS = {1}

    getter version : Int32
    property modules : Array(ModuleSpec)

    def initialize(@version, @modules)
    end

    def self.new(data : YAML::Any)
      raise "missing version field for lockfile" unless data["version"]?
      raise "missing modules field for lockfile" unless data["modules"]?

      version = data["version"].as_i
      raise "invalid version for lockfile" unless VERSIONS.includes? version
      modules = data["modules"].as_a.map { |m| ModuleSpec.new(m) }

      new version, modules
    end

    def self.fetch
      raise "eyrie lockfile not found" unless File.exists? "/var/eyrie/module.lock"
      new YAML.parse File.read("/var/eyrie/module.lock")
    end

    def self.default
      new 1, [] of ModuleSpec
    end

    def to_yaml : String
      YAML.build do |yaml|
        yaml.mapping do
          yaml.scalar "version"
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
end

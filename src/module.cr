module Eyrie
  struct Author
    property name : String?
    property contact : String?

    def initialize(@name, @contact)
    end

    def self.new(data : YAML::Any)
      new data["name"].as_s?, data["contact"].as_s?
    end

    def to_yaml(yaml : YAML::Builder) : Nil
      return unless @name

      yaml.scalar "name"
      yaml.scalar @name

      if @contact
        yaml.scalar "contact"
        yaml.scalar @contact
      end
    end
  end

  struct Source
    enum Type
      Local
      Git
      Github
      Gitlab
    end

    property uri : String
    property type : Type

    def initialize(@uri, @type)
      {% for src in %w(github gitlab) %}
      if @type.{{ src.id }}? && @uri.starts_with?("{{ src.id }}.com")
        @uri = "https://" + @uri
      end

      if @type.{{ src.id }}? && !@uri.starts_with?("https://{{ src.id }}.com")
        @uri = "https://{{ src.id }}.com/#{@uri}"
      end
      {% end %}

      @uri += ".git" unless @type.local? || @uri.ends_with?(".git")
    end

    def self.new(uri, type : String)
      new uri, Type.parse(type)
    end

    def self.new(data : YAML::Any)
      raise "missing uri for source" unless data["uri"]?
      raise "missing type for source" unless data["type"]?

      new data["uri"].as_s, data["type"].as_s
    end
  end

  struct CmdDepSpec
    property composer : Hash(String, String)?
    property npm : Hash(String, String)?

    def initialize(@composer, @npm)
    end

    def self.new(data : YAML::Any)
      composer = data["composer"]?.try &.as_h.map { |k, v| {k.as_s, v.as_s} }.to_h
      npm = data["npm"]?.try &.as_h.map { |k, v| {k.as_s, v.as_s} }.to_h

      new composer, npm
    end

    def to_yaml(yaml : YAML::Builder) : Nil
      if c = @composer
        yaml.scalar "composer"
        yaml.mapping do
          c.each do |k, v|
            yaml.scalar k
            yaml.scalar v
          end
        end
      end

      if n = @npm
        yaml.scalar "npm"
        yaml.mapping do
          n.each do |k, v|
            yaml.scalar k
            yaml.scalar v
          end
        end
      end
    end
  end

  struct Deps
    property install : CmdDepSpec?
    property remove : CmdDepSpec?

    def initialize(@install, @remove)
    end

    def self.new(data : YAML::Any)
      install = data["install"]?.try { |s| CmdDepSpec.new(s) }
      remove = data["remove"]?.try { |s| CmdDepSpec.new(s) }

      new install, remove
    end
  end

  struct Files
    property includes : Array(String)
    property excludes : Array(String)
    property mappings : Hash(String, String)
    property remove : Array(String)

    def initialize(@includes, @excludes, @mappings, @remove)
    end

    def self.new(data : YAML::Any)
      includes = data["include"].as_a.map &.as_s
      excludes = data["exclude"]?.try(&.as_a.map(&.as_s)) || [] of String
      mappings = data["mappings"]?.try(&.as_h.map { |k, v| {k.as_s, v.as_s} }.to_h) || {} of String => String
      remove = data["remove"]?.try(&.as_a.map(&.as_s)) || [] of String

      new includes, excludes, mappings, remove
    end

    def self.default
      new(
        [] of String,
        [] of String,
        {} of String => String,
        [] of String
      )
    end

    def to_yaml(yaml : YAML::Builder) : Nil
      yaml.scalar "include"
      yaml.sequence do
        @includes.each { |f| yaml.scalar(f) }
      end

      unless @excludes.empty?
        yaml.scalar "exclude"
        yaml.sequence do
          @excludes.each { |f| yaml.scalar(f) }
        end
      end

      unless @mappings.empty?
        yaml.scalar "mappings"
        yaml.mapping do
          @mappings.each do |k, v|
            yaml.scalar k
            yaml.scalar v
          end
        end
      end

      unless @remove.empty?
        yaml.scalar "remove"
        yaml.sequence do
          @remove.each { |f| yaml.scalar(f) }
        end
      end
    end
  end

  class Module
    property name : String
    property version : Version
    property authors : Array(Author)
    property source : Source
    property supports : String
    property deps : Deps
    property files : Files
    property postinstall : Array(String)

    def initialize(@name, @version, @authors, @source, @supports, @deps, @files, @postinstall)
    end

    def self.new(data : YAML::Any)
      raise "missing name field for module" unless data["name"]?
      raise "missing version field for module" unless data["version"]?
      raise "missing source field for module" unless data["source"]?
      raise "missing supported version requirement for module" unless data["supports"]?
      raise "missing file specifications for module" unless data["files"]?

      version = Version.parse data["version"].as_s
      authors = if data["authors"]?
                  data["authors"].as_a.map { |a| Author.new(a) }
                else
                  [] of Author
                end

      source = Source.new data["source"]
      deps = data["dependencies"]?.try { |d| Deps.new(d) } || Deps.new(nil, nil)
      files = Files.new data["files"]
      scripts = data["postinstall"]?.try(&.as_a.map(&.as_s)) || [] of String

      new(
        data["name"].as_s,
        version,
        authors,
        source,
        data["supports"].as_s,
        deps,
        files,
        scripts
      )
    end

    def self.from_path(path : String)
      new YAML.parse File.read(path)
    end

    def self.default
      new(
        "module-name",
        Version.new(0, 0, 1),
        [Author.new("your-name-here", "your@contact.here")],
        Source.new("uri-to-source", :local),
        "",
        Deps.new(nil, nil),
        Files.default,
        [] of String
      )
    end

    def validate(ver : SemanticVersion) : Nil
      raise Error.new(:invalid_name) if @name.matches? /[^a-z0-9_-]+/
      raise Error.new(:invalid_supports) unless @supports.matches? /^[*~<|>=^]*\d+\.\d+\.\d+[*~<|>=^]*$/
      raise Error.new(:cannot_support) unless SemanticCompare.simple_expression ver, @supports
      raise Error.new(:no_files) if @files.includes.empty?
    end

    def format(io : IO) : Nil
      authors = if @authors.empty?
                  "none set"
                else
                  @authors
                    .select(&.name)
                    .map { |a| %(- #{a.name}#{" <#{a.contact}>" if a.contact}) }
                    .join('\n')
                end

      io << <<-FMT
      name:     #{@name}
      version:  #{@version}
      authors:  #{authors}

      source:   #{@source.uri}
      type:     #{@source.type}

      supports: #{@supports}

      FMT
    end

    def to_spec : ModuleSpec
      ModuleSpec.new @name, @version, @source
    end

    def to_yaml : String
      YAML.build do |yaml|
        yaml.mapping do
          yaml.scalar "name"
          yaml.scalar @name

          yaml.scalar "version"
          yaml.scalar @version

          unless @authors.empty?
            yaml.scalar "authors"
            yaml.sequence do
              @authors.each do |author|
                yaml.mapping do
                  author.to_yaml yaml
                end
              end
            end
          end

          yaml.scalar "source"
          yaml.mapping do
            yaml.scalar "uri"
            yaml.scalar @source.uri
            yaml.scalar "type"
            yaml.scalar @source.type
          end

          yaml.scalar "supports"
          yaml.scalar @supports

          if @deps.install || @deps.remove
            yaml.scalar "dependencies"
            yaml.mapping do
              if deps = @deps.install
                yaml.scalar "install"
                yaml.mapping do
                  deps.to_yaml yaml
                end
              end

              if deps = @deps.remove
                yaml.scalar "remove"
                yaml.mapping do
                  deps.to_yaml yaml
                end
              end
            end
          end

          yaml.scalar "files"
          yaml.mapping do
            @files.to_yaml yaml
          end

          yaml.scalar "postinstall"
          yaml.sequence do
            @postinstall.each { |s| yaml.scalar(s) }
          end
        end
      end
    end
  end
end

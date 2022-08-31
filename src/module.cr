module Eyrie
  struct Author
    property name : String
    property contact : String

    def initialize(@name, @contact); end

    def self.new(data : YAML::Any)
      name = data["name"].try &.as_s
      contact = data["contact"].try &.as_s

      new(name || "", contact || "")
    end
  end

  enum SourceType
    Local
    Git
    Github
    Gitlab
  end

  struct Source
    property url : String
    property type : SourceType

    def initialize(@url, @type); end

    def initialize(@url, type : String)
      @type = case type
              when "local"  then SourceType::Local
              when "git"    then SourceType::Git
              when "github" then SourceType::Github
              when "gitlab" then SourceType::Gitlab
              else
                raise "invalid source type '#{type}'"
              end
    end

    def self.new(data : YAML::Any)
      raise "missing url for module source" unless data["url"]?
      raise "missing source type for module" unless data["type"]?

      rawtype = data["type"].as_s
      type = case rawtype
             when "local"  then SourceType::Local
             when "git"    then SourceType::Git
             when "github" then SourceType::Github
             when "gitlab" then SourceType::Gitlab
             else
               raise "invalid source type '#{rawtype}'"
             end

      new data["url"].as_s, type
    end

    def validate : Nil
      {% for src in %w(github gitlab) %}
        if @type.{{ src.id }}? && @url.starts_with?("{{ src.id }}.com")
          @url = "https://" + @url
        end

        if @type.{{ src.id }}? && !@url.starts_with?("https://{{ src.id }}.com")
          @url = "https://{{ src.id }}.com/#{@url}"
        end
      {% end %}

      @url += ".git" unless @type.local? && @url.ends_with?(".git")
    end
  end

  struct CmdDepSpec
    property composer : Hash(String, String)?
    property npm : Hash(String, String)?

    def initialize(@composer = nil, @npm = nil); end

    def self.new(data : YAML::Any)
      composer = data["composer"]?.try &.as_h.map { |k, v| {k.as_s, v.as_s} }.to_h
      npm = data["npm"]?.try &.as_h.map { |k, v| {k.as_s, v.as_s} }.to_h

      new composer, npm
    end
  end

  struct Deps
    property install : CmdDepSpec?
    property remove : CmdDepSpec?

    def initialize(@install = nil, @remove = nil); end

    def self.new(data : YAML::Any)
      install = data["install"]?.try { |s| CmdDepSpec.new s }
      remove = data["remove"]?.try { |s| CmdDepSpec.new s }

      new install, remove
    end
  end

  struct Files
    property includes : Array(String)
    property excludes : Array(String) = [] of String
    property mappings : Hash(String, String) = {} of String => String
    property remove : Array(String) = [] of String

    def initialize(@includes, @excludes, @mappings, @remove); end

    def self.new(data : YAML::Any)
      raise "missing include field for files" unless data["include"]?

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
  end

  struct Module
    property name : String
    property version : String
    property authors : Array(Author)
    property source : Source?
    property supports : String
    property deps : Deps
    property files : Files
    property postinstall : Array(String)

    def initialize(@name, @version, @authors, @source, @supports, @deps,
                   @files, @postinstall)
    end

    def self.new(data : YAML::Any)
      raise "missing name field for module" unless data["name"]?
      raise "missing version field for module" unless data["version"]?
      raise "missing supported version requirement for module" unless data["supports"]?
      raise "missing file specifications for module" unless data["files"]?

      authors = if data["authors"]?
                  data["authors"].as_a.map { |a| Author.new a }
                else
                  [] of Author
                end

      source = data["source"]?.try { |s| Source.new s }
      deps = data["dependencies"]?.try { |d| Deps.new d } || Deps.new
      files = Files.new data["files"]
      scripts = data["postinstall"]?.try(&.as_a.map(&.as_s)) || [] of String

      new(
        data["name"].as_s,
        data["version"].as_s,
        authors,
        source,
        data["supports"].as_s,
        deps,
        files,
        scripts
      )
    end

    def self.from_path(path : String)
      raise "module file path not found" unless File.exists? path
      new YAML.parse File.read(path)
    end

    def self.default
      new(
        "module-name",
        "0.0.1",
        [Author.new("your-name-here", "your@contact.here")],
        Source.new("url-to-source", :local),
        "",
        Deps.new,
        Files.default,
        [] of String
      )
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

      if @files.includes.empty?
        raise "no files included, cannot assume files to install"
      end

      @source.try &.validate
    end

    def to_spec : ModuleSpec
      ModuleSpec.new @name, @version, @source || Source.new("", :local)
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
              @authors.each do |a|
                yaml.scalar "name"
                yaml.scalar a.name
                yaml.scalar "contact"
                yaml.scalar a.contact
              end
            end
          end

          if src = @source
            yaml.scalar "source"
            yaml.mapping do
              yaml.scalar "url"
              yaml.scalar src.url
              yaml.scalar "type"
              yaml.scalar src.type
            end
          end

          yaml.scalar "supports"
          yaml.scalar @supports

          if @deps.install || @deps.remove
            yaml.scalar "dependencies"
            yaml.mapping do
              if deps = @deps.install
                if composer = deps.composer
                  unless composer.empty?
                    yaml.scalar "composer"
                    yaml.mapping do
                      composer.each do |k, v|
                        yaml.scalar k
                        yaml.scalar v
                      end
                    end
                  end
                end

                if npm = deps.npm
                  unless npm.empty?
                    yaml.scalar "npm"
                    yaml.mapping do
                      npm.each do |k, v|
                        yaml.scalar k
                        yaml.scalar v
                      end
                    end
                  end
                end
              end

              if deps = @deps.remove
                if composer = deps.composer
                  unless composer.empty?
                    yaml.scalar "composer"
                    yaml.mapping do
                      composer.each do |k, v|
                        yaml.scalar k
                        yaml.scalar v
                      end
                    end
                  end
                end

                if npm = deps.npm
                  unless npm.empty?
                    yaml.scalar "npm"
                    yaml.mapping do
                      npm.each do |k, v|
                        yaml.scalar k
                        yaml.scalar v
                      end
                    end
                  end
                end
              end
            end
          end

          yaml.scalar "files"
          yaml.mapping do
            yaml.scalar "include"
            yaml.sequence do
              @files.includes.each { |f| yaml.scalar f }
            end

            unless @files.excludes.empty?
              yaml.scalar "exclude"
              yaml.sequence do
                @files.excludes.each { |f| yaml.scalar f }
              end
            end

            unless @files.mappings.empty?
              yaml.scalar "mappings"
              yaml.mapping do
                @files.mappings.each do |k, v|
                  yaml.scalar k
                  yaml.scalar v
                end
              end
            end

            unless @files.remove.empty?
              yaml.scalar "remove"
              yaml.sequence do
                @files.remove.each { |f| yaml.scalar f }
              end
            end
          end

          yaml.scalar "postinstall"
          yaml.sequence do
            @postinstall.each { |s| yaml.scalar s }
          end
        end
      end
    end
  end
end

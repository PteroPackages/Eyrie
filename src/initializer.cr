module Eyrie::Initializer
  def self.run(force : Bool, skip : Bool) : Nil
    mod_path = File.join Dir.current, "eyrie.yml"

    if File.exists?(mod_path) && !force
      Log.error ["Module file already exists in this directory", "Run with the '--force' flag to overwrite"]
      return
    end

    unless skip
      if STDIN.tty? && !STDIN.closed?
        return run_interactive mod_path
      else
        Log.warn ["Stdin input is not supported by this terminal", "Skipping interactive module setup"]
      end
    end

    begin
      tmpl = ECR.render "src/module.ecr"
      File.write mod_path, tmpl
      Log.info "Created module file at:\n#{mod_path}"
    rescue ex
      Log.error ex, "Failed to write to module file"
    end
  end

  private def self.run_interactive(path : String) : Nil
    Signal::INT.trap do
      Log.info "\n\nExiting module setup"
      exit
    end

    Log.info [
      "Welcome to the Eyrie interactive module setup",
      "This setup will walk you through creating an eyrie module file",
      "If you want to skip this setup, exit and run 'eyrie init --skip'",
      "Press '^C' (Ctrl+C) at any time to exit\n\n",
    ]

    mod = Module.default
    mod.authors.clear
    author = Author.new "your-name-here", "your@contact.here"
    source = Source.new "url-to-source", :local

    prompt("module name: ", can_skip: false) do |value|
      if value.matches? /[^a-z0-9_-]+/
        raise "name can only contain lowercase letters, numbers, dashes, and underscores"
      end

      mod.name = value
    end

    prompt("version: (0.0.1) ", default: "0.0.1") do |value|
      begin
        mod.version = Version.parse value
      rescue
        raise "Invalid version format, must follow semver spec 'major.minor.patch' (no requirements)"
      end
    end

    prompt("author name: (your-name-here) ") { |v| author.name = v }
    prompt("author contact: (your@contact.here) ") { |v| author.contact = v }
    prompt("source: (uri-to-source) ") do |value|
      source.uri = value

      case value
      when .includes? "github" then source.type = :github
      when .includes? "gitlab" then source.type = :gitlab
      when .includes? "git"    then next # default is git
      else
        Log.info "Assuming source type is local (you can change this after)"
        source.type = :local
      end
    end

    prompt("supports: ", can_skip: false) do |value|
      unless value.matches? /[*~<|>=^]*\d+\.\d+\.\d+[*~<|>=^]*/
        raise "Invalid version format, must follow semver spec 'major.minor.patch' (requirements allowed)"
      end

      mod.supports = value
    end

    mod.authors << author
    mod.source = source

    begin
      File.write path, mod.to_yaml
      Log.info "\nCreated module file at:\n#{path}"
    rescue ex
      Log.error ex, "Failed to write to module file"
    end
  end

  private def self.prompt(message : String, *, can_skip : Bool = true, default : String? = nil, & : String ->) : Nil
    loop do
      Log.write message
      input = STDIN.gets || ""
      input = default if default && input.empty?

      if input.empty?
        break if can_skip
        next Log.error "Cannot accept empty value"
      end

      begin
        yield input
        break
      rescue ex
        Log.error ex.message.not_nil!
      end
    end
  end
end

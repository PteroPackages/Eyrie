require "semantic_version"
require "./package"

module Eyrie::Initializer
  def self.init_lockfile(force : Bool) : Nil
    if File.exists?(LOCK_PATH) && !force
      Log.error "lockfile already exists in this directory"
      return
    end

    File.write LOCK_PATH, LockSpec.new.to_yaml
    Log.info "created lockfile at:\n#{LOCK_PATH}"
  rescue ex
    Log.error ex, "failed to write to lockfile"
  end

  def self.init_module_file(force : Bool, skip : Bool, newline : Bool) : Nil
    if File.exists?(MOD_PATH) && !force
      Log.error "module file already exists in this directory"
      return
    end

    unless skip
      if can_read_term?
        return init_interactive_setup newline
      else
        Log.warn [
          "stdin input is not supported by this terminal",
          "skipping interactive module setup"
        ]
      end
    end

    begin
      File.write MOD_PATH, Module.new.to_yaml
      Log.info "created module file at:\n#{MOD_PATH}"
    rescue ex
      Log.error ex, "failed to write to module file"
    end
  end

  private def self.can_read_term? : Bool
    !STDIN.closed?
  end

  private def self.init_interactive_setup(newline : Bool) : Nil
    setup_trap

    Log.info [
      "#{"\n" if newline}Welcome to the Eyrie interactive module setup",
      "This setup will walk you through creating an eyrie module file",
      "If you want to skip this setup, exit and run 'eyrie init --skip'",
      "Press '^C' (Ctrl+C) at any time to exit\n\n"
    ]

    mod = Module.new
    mod.authors.clear
    author = Author.new "your-name-here", "your@contact.here"
    source = Source.new "url-to-source"

    prompt("module name: ", can_skip: false) do |value|
      if value =~ %r[[^a-z0-9_-]]
        raise "name can only contain lowercase letters, numbers, dashes, and underscores"
      end

      mod.name = value
    end

    prompt("version: (0.0.1) ", default: "0.0.1") do |value|
      begin
        SemanticVersion.parse value
        mod.version = value
      rescue
        raise "invalid version format, must follow semver spec (no requirements)"
      end
    end

    prompt("author name: (your-name-here) ") { |v| author.name = v }
    prompt("author contact: (your@contact.here) ") { |v| author.contact = v }
    prompt("source: (url-to-source) ") do |value|
      source.url = value

      case value
      when .includes? "github"  then source.type = :github
      when .includes? "gitlab"  then source.type = :gitlab
      when .includes? "git"     then next # default is git
      else
        Log.info "assuming source type is local (you can change this after)"
        source.type = :local
      end
    end

    prompt("supports: ", can_skip: false) do |value|
      unless value =~ %r[[*~<|>=^]*\d+\.\d+\.\d+[*~<|>=^]*]
        raise "invalid version format, must follow semver spec"
      end

      mod.supports << value
    end

    mod.authors << author
    mod.source = source

    begin
      File.write MOD_PATH, mod.to_yaml
      Log.info "\ncreated module file at:\n#{MOD_PATH}"
    rescue ex
      Log.error ex, "failed to write to module file"
    end
  end

  private def self.setup_trap : Nil
    {% if flag?(:win32) %}
      # not possible yet?
    {% else %}
      Signal::INT.trap do
        Log.info "\n\nExiting module setup"
        exit
      end
    {% end %}
  end

  private def self.prompt(message : String, *, can_skip : Bool = true,
                          default : String? = nil, &block : String ->)
    loop do
      STDOUT << message
      input = STDIN.gets || ""
      input = default if default && input.empty?

      if input.empty?
        break if can_skip
        next Log.error "cannot accept empty value"
      end

      begin
        block.call input
        break
      rescue ex
        Log.error ex.message.not_nil!
      end
    end
  end
end

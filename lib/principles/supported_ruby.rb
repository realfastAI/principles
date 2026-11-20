# typed: strict
# frozen_string_literal: true

module Principles
  # The Ruby this tool runs on. exe/principles loads this before anything else, so an agent on a Ruby too old to
  # parse lib/ still gets this tool's JSON refusal, not a SyntaxError. So this file stays in syntax any Ruby 2
  # parses, and requires only rbconfig: a GEM_HOME left by another Ruby can hand an old Ruby a json it cannot
  # parse. When the Ruby running is unsupported, it looks for a supported one that rbenv installed, since
  # rbenv otherwise picks Ruby by the directory this tool runs in, and runs this tool on that instead.
  # Its bounds equal the gemspec's required_ruby_version; a spec checks it.
  class SupportedRuby
    MINIMUM = [3, 4, 2].freeze #: Array[Integer]
    BELOW = [3, 5].freeze #: Array[Integer]
    # Set on the process this tool hands itself to, so a Ruby that is not what its folder name says cannot
    # hand it on again.
    HANDED_OFF = "PRINCIPLES_HANDED_TO_RUBY"

    #: (String, Hash[String, String]) -> void
    def initialize(running, environment)
      @running = running
      @environment = environment
    end

    # Returns when this Ruby is supported; otherwise runs executable on a supported rbenv Ruby, or prints the
    # refusal and exits 1.
    #: (String, Array[String]) -> void
    def run_here_or_on_another(executable, arguments)
      step = next_step(executable, arguments)
      return if step.key?("run_here")

      if step.key?("hand_to")
        process = Kernel #: as untyped
        process.exec(*step.fetch("hand_to"))
      end
      warn step.fetch("refuse")
      exit 1
    end

    # What this tool does on this Ruby, decided without acting: run_here; hand_to, the arguments for Kernel.exec
    # that run executable on a supported rbenv Ruby; or refuse, the refusal to print before exiting 1.
    #: (String, Array[String]) -> Hash[String, untyped]
    def next_step(executable, arguments)
      return { "run_here" => true } if supported?(@running)

      other = rbenv_ruby
      if other && !@environment[HANDED_OFF]
        return { "hand_to" => [{ HANDED_OFF => other }, other, executable, *arguments] }
      end

      { "refuse" => refusal(setup_skill(executable)) }
    end

    private

    #: (String) -> bool
    def supported?(version)
      numbers = version.split(".").map(&:to_i)
      (numbers <=> MINIMUM) >= 0 && (numbers <=> BELOW).negative?
    end

    # The newest supported Ruby among rbenv's installed versions, if any.
    #: () -> String?
    def rbenv_ruby
      root = @environment["RBENV_ROOT"] || File.join(@environment["HOME"].to_s, ".rbenv")
      found = Dir.glob(File.join(root, "versions", "*", "bin", "ruby")).select do |ruby|
        supported?(version_of(ruby)) && File.executable?(ruby)
      end
      found.max_by { |ruby| version_of(ruby).split(".").map(&:to_i) }
    end

    # The version rbenv installed ruby as: the name of its folder under versions/.
    #: (String) -> String
    def version_of(ruby)
      # File.dirname's level argument needs Ruby 3.1, and this runs on older Rubies.
      File.basename(File.dirname(File.dirname(ruby))) # rubocop:disable Style/NestedFileDirname
    end

    # The setup-ruby skill's file beside the plugin's bin/ that executable is in, if there is one: a skill that
    # never loads itself, so the refusal names its file for the agent to read.
    #: (String) -> String?
    def setup_skill(executable)
      plugin = File.dirname(File.dirname(executable)) # rubocop:disable Style/NestedFileDirname
      skill = File.join(plugin, "skills", "setup-ruby", "SKILL.md")
      skill if File.file?(skill)
    end

    # This tool's refusal as JSON, written by hand because json may not load here.
    #: (String?) -> String
    def refusal(skill_file)
      require "rbconfig"
      needed = ">= #{MINIMUM.join(".")} and < #{BELOW.join(".")}"
      fields = [%w[status refused], %w[code unsupported_ruby],
                ["message", "This tool needs Ruby #{needed}; this is Ruby #{@running} at #{RbConfig.ruby}, and rbenv " \
                            "has no Ruby it supports"],
                ["repair", repair(skill_file, needed)]]
      quoted = fields.map { |pair| pair.map { |text| "\"#{text.gsub(/[\\"]/) { |c| "\\#{c}" }}\"" }.join(":") }
      "{#{quoted.join(",")}}"
    end

    # How to get a supported Ruby: by the plugin's setup-ruby skill when its file is here, otherwise with rbenv.
    #: (String?, String) -> String
    def repair(skill_file, needed)
      return "Read #{skill_file} and follow it, asking the user before installing anything." if skill_file

      "In Claude Code with the principles plugin, ask the user to run /principles:setup-ruby, which installs one " \
        "with rbenv and ruby-build. Otherwise install a Ruby #{needed} with rbenv; it finds any rbenv Ruby it " \
        "supports, whatever directory it runs in."
    end
  end
end

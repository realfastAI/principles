# typed: strict
# frozen_string_literal: true

require "optparse"
require_relative "invocation_options"
require_relative "after_commit_hook_options"
require_relative "session_start_options"
require_relative "list_open_findings_options"
require_relative "list_principles_options"
require_relative "start_audit_options"
require_relative "models/command_steps"
require_relative "prose_list"
require_relative "positional_arguments"

module Principles
  # One invocation's words: the command, its positional arguments and its options, refused with an
  # OptionParser error when they do not fit what the command takes. CLI decides what to run from it.
  class CommandLine
    # How a refusal names each option a command requires.
    REQUIRED_OPTION_WORDS = { "file" => "--file FILE, or --file - for stdin" }.freeze #: Hash[String, String]

    # argv is parsed at once; positional names each command's positional arguments, in order; executable is the
    # invocation a refusal tells the agent to run --help with.
    #: (Array[String], positional: Hash[String, Array[String]], executable: String) -> void
    def initialize(argv, positional:, executable:)
      @positional = positional
      @executable = executable
      @options = InvocationOptions.new #: InvocationOptions
      @arguments = argv.dup #: Array[String]
      # The words as typed: parsing takes the options out of @arguments, and a value option is checked against
      # the word that followed it.
      @words = argv.dup.freeze #: Array[String]
      parse(argv)
    end

    # A usage refusal that carries the repair for the command it names, which CLI prints in place of its
    # general advice. It stays an OptionParser::ParseError, so it exits 2 like every usage refusal.
    class UsageRefusal < OptionParser::ParseError
      #: String
      attr_reader :repair

      #: (String, String) -> void
      def initialize(fault, repair)
        super()
        @fault = fault
        @repair = repair
      end

      #: () -> String
      def message = @fault
    end

    # A parsed option's value, or true for a flag that was given.
    #: (String) -> untyped
    def option(name)
      @options.value(name)
    end

    # Explicit selection defines a project even when it names the current directory.
    #: () -> bool
    def project_given? = @options.given.include?("project")

    # Whether the words ask for help by word, as help or help COMMAND, which an agent tries before --help.
    #: () -> bool
    def help_words? = @arguments.first == "help"

    # The command help COMMAND names, or nil for help alone.
    #: () -> String?
    def help_topic = @arguments[1]

    # The command named first; nil when none is, and refused when this tool has no such command.
    #: () -> String?
    def command
      name = @arguments.first or return nil
      return name if @positional.key?(name)

      raise OptionParser::InvalidArgument, "unknown command #{name}"
    end

    # Refuses every missing argument at once, too many arguments, an option the command does not take or given an
    # option as its value.
    #: () -> void
    def check
      name = command.to_s
      check_missing(name)
      check_arguments(name)
      check_options(name)
      check_values_are_not_options(name)
      check_combined_options(name)
    end

    # The principle id, for a command whose first argument is one.
    #: () -> String?
    def id
      positionals.id
    end

    # The options, with every positional argument but the id under its name; project only when --project was given,
    # so a command's printed commands name it only then.
    #: () -> Hash[String, untyped]
    def command_options
      options = @options.to_h.merge(positionals.bindings)
      project_given? ? options : options.except("project")
    end

    private

    #: () -> PositionalArguments
    def positionals = PositionalArguments.new(@positional.fetch(command.to_s), @arguments.drop(1))

    # Each argument the command needs and was not given, named in one refusal: an agent that met one refusal per
    # missing argument repaired them one at a time. Each option command-steps.json says it requires is one.
    # The repair names the command's usage, which shows what to give.
    #: (String) -> void
    def check_missing(name)
      missing = positionals.missing + missing_options(name)
      return if missing.empty?

      raise UsageRefusal.new("missing argument: #{name} needs #{ProseList.new(missing)}", help_repair(name))
    end

    # The options command name requires and was not given, as a refusal names them.
    #: (String) -> Array[String]
    def missing_options(name)
      required = steps(name)&.requires || []
      required.reject { |option| @options.value(option) }.map { |option| REQUIRED_OPTION_WORDS.fetch(option) }
    end

    # Too many arguments; check_missing has refused too few.
    #: (String) -> void
    def check_arguments(name)
      return unless positionals.too_many?

      takes = "#{name} takes #{positionals.shown}".strip.sub(/ takes\z/, " takes no arguments")
      raise OptionParser::InvalidArgument, takes
    end

    # An option a command does not take is refused, so a mistyped command never runs as something else.
    #: (String) -> void
    def check_options(name)
      taken = steps(name)&.options || []
      unknown = (@options.given - taken - ["project"]).map { |option| "--#{option}" }
      return if unknown.empty?

      raise UsageRefusal.new("#{name} does not take #{unknown.join(", ")}", help_repair(name))
    end

    # An option that takes a value takes the next word, whatever it is, so --member --help took --help as the member.
    # Only this tool's own option words are refused there, since a quote may start with dashes; such a word is
    # given as a value after =, as --starting-at=--role is.
    #: (String) -> void
    def check_values_are_not_options(name)
      @words.each_cons(2) do |pair|
        option = pair.fetch(0)
        value = pair.fetch(1)
        next unless InvocationOptions.takes_a_value?(option) && InvocationOptions::WORDS.include?(value)

        raise UsageRefusal.new("#{option} takes a value, not the option #{value}; to give that word as its value, " \
                               "write #{option}=#{value}", help_repair(name))
      end
    end

    # Options checked together, each set owning what is wrong with it as given: --session-start, the
    # after-commit hook's pair on the command it runs, the audit start-audit begins and the forms
    # list-open-findings and list-principles print; the first fault is refused.
    #: (String) -> void
    def check_combined_options(name)
      hook = (AfterCommitHookOptions.new(@options) if name == AfterCommitHookOptions::COMMAND)
      principles = (ListPrinciplesOptions.new(@options) if name == ListPrinciplesOptions::COMMAND)
      start_audit = StartAuditOptions.new(@options, several_ids: several_ids?(name))
      sets = [SessionStartOptions.new(@options), hook, start_audit, ListOpenFindingsOptions.new(@options),
              principles].compact
      fault = sets.filter_map(&:fault).first or return
      raise UsageRefusal.new(fault, help_repair(name))
    end

    # Whether command name is start-audit given more than one principle id.
    #: (String) -> bool
    def several_ids?(name) = name == "start-audit" && !positionals.bindings.fetch("other_ids", []).empty?

    # Parses argv's options; an option no command defines fails here, before the command is checked, and is
    # repaired with the help of the command argv names, or left to CLI's general advice when it names none.
    #: (Array[String]) -> void
    def parse(argv)
      @options.parse!(@arguments)
    rescue OptionParser::InvalidOption => e
      name = named_command(argv) or raise
      raise UsageRefusal.new(e.message, help_repair(name))
    end

    # The first word that names a command. The command comes first among the positional words, but an option
    # and its value may come before it; a value that is itself a command's name leads to that command's help.
    #: (Array[String]) -> String?
    def named_command(argv) = argv.find { |word| @positional.key?(word) }

    # What command-steps.json says of the command name, or nil for a name it does not list.
    #: (String) -> Models::CommandSteps::Command?
    def steps(name) = Models::CommandSteps.load.command(name)

    # The command's usage, which names every option it takes, so a near-miss such as --heading for --section shows
    # beside the refusal, then where to see what each takes. The usage leaves out the executable, so it is not
    # read as a command to run as printed.
    #: (String) -> String
    def help_repair(name)
      usage = steps(name)&.usage or return "To see what it takes: #{@executable} #{name} --help"
      "Usage: #{usage}\nTo see what each takes: #{@executable} #{name} --help"
    end
  end
end

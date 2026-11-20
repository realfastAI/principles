# typed: strict
# frozen_string_literal: true

module Principles
  # A refusal: a stable code, what went wrong and how to repair it, printed as one JSON object.
  class Error < StandardError
    # Stands in a model's repair for the running executable, which only the controller knows. The
    # controller puts the executable in with #naming before the refusal is printed.
    EXECUTABLE = "{executable}"

    # A command a refusal's repair names for values it holds, such as a member id, left unquoted, since a model
    # cannot quote: the controller prints it through Views::Invocation, the one owner of shell quoting, after its
    # purpose and a colon, on a line of its own. options are flags with their values, quoted the same
    # way; usage is this tool's own placeholder text, such as "--role ROLE", left for the agent to fill.
    class RepairCommand
      #: String
      attr_reader :purpose, :command
      #: Array[String]
      attr_reader :values, :options
      #: String?
      attr_reader :usage

      #: (purpose: String, command: String, values: Array[String], ?options: Array[String], ?usage: String?) -> void
      def initialize(purpose:, command:, values:, options: [], usage: nil)
        @purpose = purpose
        @command = command
        @values = values
        @options = options
        @usage = usage
        freeze
      end
    end

    #: Hash[String, untyped]
    attr_reader :payload

    # fields are the failing JSON pointers of a malformed file or answer, each with what is wrong there.
    #: (String, String, String, ?String?, ?fields: Array[Hash[String, String]]?) -> void
    def initialize(code, message, repair, path = nil, fields: nil)
      super(message)
      @payload = { "status" => "refused", "code" => code, "message" => message,
                   "repair" => repair } #: Hash[String, untyped]
      @payload["path"] = path if path
      @payload["fields"] = fields if fields
      @commands = [] #: Array[RepairCommand]
    end

    # The repair's commands still to print, which follow its text.
    #: Array[RepairCommand]
    attr_reader :commands

    # This refusal with commands, which its repair names after its text, for the controller to print.
    #: (Array[RepairCommand]) -> Error
    def ending_with(commands)
      @commands = commands
      self
    end

    # This refusal with more of what it is about, such as the members it lists, each with its own refusal.
    #: (Hash[String, untyped]) -> Error
    def including(details)
      @payload.merge!(details)
      self
    end

    # This refusal with each of its commands printed by the block, after its purpose, a line each after the repair's
    # text.
    #: () { (RepairCommand) -> String } -> Error
    def printing_commands(&)
      return self if @commands.empty?

      lines = @commands.map { |command| "#{command.purpose}: #{yield(command)}" }
      repaired([payload.fetch("repair"), *lines].reject(&:empty?).join("\n"), [])
    end

    # This refusal, when it names under did_you_mean the one mapped id an id it was given nearly matches, with its
    # repair led by the command the block prints for that id; this tool never runs a command on the near miss
    # itself. Otherwise this refusal as it is.
    #: () { (String) -> String } -> Error
    def rerun_with_near_miss(&)
      mapped = payload["did_you_mean"] or return self
      repaired("To run it with that id: #{yield(mapped)}\n#{payload.fetch("repair")}")
    end

    # This refusal with executable in place of each EXECUTABLE its repair names.
    #: (String) -> Error
    def naming(executable)
      repaired(payload.fetch("repair").gsub(EXECUTABLE, executable))
    end

    private

    # This refusal with repair in place of its own, keeping everything else.
    #: (String, ?Array[RepairCommand]) -> Error
    def repaired(repair, commands = @commands)
      copy = Error.new(payload.fetch("code"), payload.fetch("message"), repair).including(payload.except("repair"))
                  .ending_with(commands)
      copy.set_backtrace(backtrace || [])
      copy
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "json"
require_relative "models/project"
require_relative "command_routes"
require_relative "controllers/help"
require_relative "command_line"
require_relative "failure_refusal"
require_relative "launch"
require_relative "data/hook_input"
require_relative "views/printed_json"

module Principles
  # Parses one invocation, runs its step and prints the JSON result. Every refusal is one JSON object
  # naming its code and repair, because an agent's shell may merge stdout and stderr.
  class CLI
    # The repair for a shape error raised from this tool's own code, which FailureRefusal owns.
    SHAPE_REPAIR = FailureRefusal::SHAPE_REPAIR

    # Runs one invocation and returns its exit status: 0 for a result, 1 for a refusal, 2 for a usage error, and 3
    # when list-member-problems --short finds a member an audit assessed changed, or 4 when it finds only edits to
    # members no audit has assessed. executable is the command every printed command
    # names: the entry point says how it is run.
    #: (Array[String], ?IO, ?IO, ?IO, ?executable: String) -> Integer
    def self.run(argv, stdout = $stdout, stderr = $stderr, stdin = $stdin,
                 executable: Controllers::Command::INVOCATION)
      new(stdout, stderr, stdin, executable: executable).run(argv)
    end

    #: (IO, IO, IO, executable: String) -> void
    def initialize(stdout, stderr, stdin, executable:)
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
      @executable = executable
    end

    #: (Array[String]) -> Integer
    def run(argv)
      hook = hook_command(argv)
      hook ? run_for_a_hook(hook, argv) : run_refusing(argv)
    end

    private

    # Runs argv, refusing what does not fit with one JSON object on stderr and its status.
    #: (Array[String]) -> Integer
    def run_refusing(argv)
      dispatch(command_line(argv))
    rescue Error => e
      refused(e.payload, 1)
    rescue OptionParser::ParseError, KeyError, TypeError, NoMethodError, ArgumentError, SystemCallError => e
      failed = FailureRefusal.new(e, executable: running_tool.executable)
      refused(failed.payload, failed.status)
    end

    # Runs argv for the hook that runs command, which exits 0 whatever fails, since a host shows the user an error for
    # any other status and gives the agent nothing: a failure is one line the agent reads instead.
    #: (String, Array[String]) -> Integer
    def run_for_a_hook(command, argv)
      dispatch(command_line(argv))
    rescue StandardError => e
      @stdout.puts(visible("principles: #{command} failed: #{e.class}: #{e.message.lines.first.to_s.chomp}"))
      0
    end

    # The command argv names first when a hook runs it, as a host names it, passing its JSON on stdin, or nil for any
    # other: a hook command's name later in argv is another command's argument.
    #: (Array[String]) -> String?
    def hook_command(argv) = argv.first.then { it if CommandRoutes::ROUTES[it]&.reads_hook_input }

    #: (Array[String]) -> CommandLine
    def command_line(argv)
      CommandLine.new(argv, positional: CommandRoutes::POSITIONAL, executable: running_tool.executable)
    end

    #: (CommandLine) -> Integer
    def dispatch(line)
      return printed(running_version) if line.option("version")

      return printed(help_topic(line)) if line.help_words?

      command = line.command or return printed(help.overview)
      return printed(help_for(command)) if line.option("help")

      line.check
      printed_result(result(command, line))
    end

    # The command's result, from the controller for its group.
    #: (String, CommandLine) -> untyped
    def result(command, line)
      options = line.command_options
      # One byte past the limit is enough for the answer's own check to refuse it as too large.
      options["stdin"] = @stdin.read(Data::BoundedFile::LIMIT + 1).to_s if options["file"] == "-"
      options["stdin"] = hook_input if CommandRoutes::ROUTES.fetch(command).reads_hook_input
      project = selected_project(line)
      CommandRoutes::CONTROLLERS.fetch(command).new(project, tool: running_tool)
                                .call(command, line.id, options)
    end

    # The JSON a host passes the hook that runs this command.
    #: () -> String
    def hook_input = Data::HookInput.new(@stdin).text

    #: (CommandLine) -> Models::Project
    def selected_project(line)
      root = line.option("project")
      line.project_given? ? Models::Project.at(root) : Models::Project.containing(root)
    end

    # Prints the refusal for the agent and returns the exit status.
    #: (Hash[untyped, untyped], Integer) -> Integer
    def refused(payload, status)
      @stderr.puts(visible(JSON.generate(payload)))
      status
    end

    # json with every invisible formatting character and line or paragraph separator escaped, as JSON allows.
    # Text from project files can hold a right-to-left override or a zero-width space, which makes a printed
    # check or id look like something it is not.
    #: (String) -> String
    def visible(json)
      json.gsub(/[\p{Cf}\p{Zl}\p{Zp}]/) do |character|
        character.encode("UTF-16BE").unpack("n*").map { |unit| format("\\u%04x", unit) }.join
      end
    end

    # A result prints as JSON, as JSON laid out with one entry a line, as list-candidate-files does, or as lines with
    # their own exit status, as list-member-problems --short does.
    #: (untyped) -> Integer
    def printed_result(result)
      return printed(visible(result.text)) if result.is_a?(Views::JsonWithEntriesOnLines)
      return printed(visible(Views::PrintedJson.text(result))) unless result.is_a?(Views::Lines)

      @stdout.print(result.stdout)
      @stderr.print(result.stderr)
      result.status
    end

    #: (String) -> Integer
    def printed(text)
      @stdout.puts(text)
      0
    end

    #: () -> Controllers::Help
    def help
      Controllers::Help.new(tool: running_tool)
    end

    # This run of the tool, as its entry point launched it.
    #: () -> Controllers::RunningTool
    def running_tool = Launch.new(@executable).running_tool

    # The version of this tool that is running, as --version prints it.
    #: () -> String
    def running_version = running_tool.version

    # The page help COMMAND asks for, as COMMAND --help prints it, or the overview for help alone.
    #: (CommandLine) -> String
    def help_topic(line)
      topic = line.help_topic
      topic ? help_for(topic) : help.overview
    end

    # A command's --help, from the steps command-steps.json lists for it.
    #: (String) -> String
    def help_for(command)
      help.command(command) || raise(OptionParser::InvalidArgument, "#{command} has no help")
    end
  end
end

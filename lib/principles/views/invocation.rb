# typed: strict
# frozen_string_literal: true

require_relative "shell_word"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How the running tool is invoked, so a printed command names the executable and project that are
    # running now. A controller builds it for each run; a view uses it to print commands, and it is never
    # stored (alpha 008 friction 16).
    class Invocation
      #: String
      attr_reader :executable
      #: String
      attr_reader :project

      # named says whether each command names the project; without_project leaves it out. temp_directory is the
      # folder a printed next step saves an answer in: the project's ignored tmp/ when it has one, else the temporary
      # folder the running tool was given.
      #: (executable: String, project: String, temp_directory: String, ?named: bool) -> void
      def initialize(executable:, project:, temp_directory:, named: true)
        @executable = executable
        @project = project
        @temp_directory = temp_directory
        @named = named
        freeze
      end

      # The same invocation, its commands leaving out --project, for output that names the project once and whose
      # commands run from there, as list-member-problems --short's stderr does.
      #: () -> Invocation
      def without_project
        Invocation.new(executable: @executable, project: @project, temp_directory: @temp_directory, named: false)
      end

      # Whether each command names the project.
      #: () -> bool
      def named? = @named

      # The project as a shell word, as --project gives it.
      #: () -> String
      def project_word = shell_word(@project)

      # A command to run in this project, which it names right after the executable, as model repairs do.
      # Each value is shell-quoted, because ids, paths and headings come from project files that anyone may have
      # written. options are flags with their values, such as
      # ["--starting-at", text], quoted the same way. usage is this tool's own placeholder text, such as
      # "--section HEADING", left for the agent to fill and never quoted. When a value starts with "-", as a
      # path may, every option comes first and "--" ends them, so the value is not read as an option.
      #: (String, *String, ?options: Array[String], ?usage: String?) -> String
      def in_project(command, *values, options: [], usage: nil) = listed_in_project(command, values, options:, usage:)

      # The command that answers request request_id in this project: from file, the --file value an answer was
      # checked from, as given, or before there is one, from a FILE the agent names.
      #: (String, ?file: String?) -> String
      def submit_answer(request_id, file: nil)
        return in_project("submit-answer", request_id, usage: "--file FILE") unless file

        in_project("submit-answer", request_id, options: ["--file", file])
      end

      # The file to save the answer name names in, a request id or a principle id, by its full path in temp_directory,
      # so every shell that runs the printed commands names the same file: a sandboxed and an unsandboxed one
      # read $TMPDIR as different folders.
      #: (String) -> String
      def answer_file(name) = "#{@temp_directory.chomp("/")}/principles-#{name}-answer.json"

      # The same command, its values given as one list, as a refusal's repair command holds them.
      #: (String, Array[String], ?options: Array[String], ?usage: String?) -> String
      def listed_in_project(command, values, options: [], usage: nil)
        flags = options.map { |value| shell_word(value) }
        words = values.map { |value| shell_word(value) }
        if values.any? { |value| value.start_with?("-") }
          return [@executable, named_project, command, *flags, usage, "--", *words].compact.join(" ")
        end

        [@executable, named_project, command, *words, *flags, usage].compact.join(" ")
      end

      #: () -> String
      def project_option
        "--project #{shell_word(@project)}"
      end

      # What each command starts with: the executable, then --project and the project unless they are left out.
      #: () -> String
      def prefix = [@executable, named_project].compact.join(" ")

      private

      # --project and the project, or nil when the commands leave it out.
      #: () -> String?
      def named_project = @named ? project_option : nil

      #: (String) -> String
      def shell_word(value) = ShellWord.new(value).to_s
    end
  end
end

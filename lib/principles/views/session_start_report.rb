# typed: strict
# frozen_string_literal: true

require_relative "problem_lines"
require_relative "invocation"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # report-at-session-start's output: each line a session start adds to the agent's context, marked as this tool's,
    # since the context holds other hooks' lines too, and exit 0, the only status on which a host adds them.
    class SessionStartReport
      # Every line's mark.
      MARK = "principles: "

      #: (Array[String]) -> void
      def initialize(lines)
        @lines = lines
        freeze
      end

      # The line naming another principles earlier on PATH, at path, which prints version, where the running copy
      # is running: a bare principles command runs that one.
      #: (String, String, String) -> String
      def self.other_version(path, version, running)
        "the principles on PATH, #{path}, is #{version}, not this plugin's #{running}, so a bare principles command " \
          "runs #{version}. Ask the user to update or remove that copy."
      end

      # This report, followed by lines.
      #: (Array[String]) -> SessionStartReport
      def followed_by(lines) = SessionStartReport.new([*@lines, *lines])

      # This report, ending as list-member-problems refused with code: the code, and the command, as invocation names
      # it, whose refusal says why and how to repair it.
      #: (String, Invocation) -> SessionStartReport
      def refused(code, invocation)
        SessionStartReport.new([*@lines, "list-member-problems refused with #{code}. To see why and how to repair " \
                                         "it, run:\n#{invocation.in_project("list-member-problems")}"])
      end

      #: () -> Lines
      def printed = Lines.new(stdout: @lines.map { "#{MARK}#{it}\n" }.join, stderr: "", status: 0)
    end
  end
end

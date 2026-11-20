# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "member_problems_report"
require_relative "audit"
require_relative "../models/session_start_input"
require_relative "../views/session_start_report"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # report-at-session-start, which a SessionStart hook runs: what the agent should act on as its session starts,
    # read from the hook's JSON on stdin. It exits 0 whatever it finds, since the host adds the hook's stdout to the
    # context only then, and prints nothing when there is nothing to act on.
    class SessionStartReport < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          unknown(command) unless command == "report-at-session-start"

          printed(Models::SessionStartInput.new(options["stdin"].to_s))
        end
      end

      private

      # The lines the session starts with, from the hook's input: from the plugin, any other version on PATH, then
      # what list-member-problems reports of the members, then the open findings; none of those in a project with no
      # maps. A refusal is named by its code, with the command that shows its repair, since a hook exiting 1 shows the
      # user an error and gives the agent nothing.
      #: (Models::SessionStartInput) -> Views::Lines
      def printed(input)
        first = Views::SessionStartReport.new(other_version)
        begin
          first.followed_by(@principles.ids.empty? ? [] : reported(input.source))
        rescue Error => e
          first.refused(e.payload.fetch("code"), invocation.without_project)
        end.printed
      end

      # From the plugin's bin, the line naming another version of principles earlier on PATH, which a bare principles
      # command runs in place of the plugin's; none from the command line, where the copy on PATH is this one. The
      # running version is read only once another copy is found, since in a checkout reading it asks git.
      #: () -> Array[String]
      def other_version
        return [] unless @tool.runs_from.session_start_hook_in_this_session?

        other = @tool.other_on_path or return []
        running = @tool.version
        other.shadows?(running) ? [Views::SessionStartReport.other_version(other.path, other.version, running)] : []
      end

      # Each line the session starts with, source: startup, resume, clear or compact.
      #: (String) -> Array[String]
      def reported(source)
        handed(MemberProblemsReport).session_start_lines(source) + handed(Audit).session_start_open_findings(source)
      end
    end
  end
end

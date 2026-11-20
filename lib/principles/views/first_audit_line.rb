# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The session-start line asking for one background subagent to run a first full audit, while any principle
    # awaits one. It counts them and names none, so its length stays fixed however many there are.
    class FirstAuditLine
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The line, as a list of none or one, for count principles awaiting a first full audit, at the session's start
      # from source: startup, resume, clear or compact. A resumed or compacted session may have a subagent running
      # already from the line its context began with, so its line gives the count alone and asks for none.
      #: (Integer, String) -> Array[String]
      def lines(count, source)
        return [] if count.zero?

        counted = count == 1 ? "1 principle has" : "#{count} principles have"
        [%w[resume compact].include?(source) ? started_already(counted, count) : asked(counted, count)]
      end

      private

      #: (String, Integer) -> String
      def started_already(counted, count)
        Prompts.text("start-a-session/start-no-second-first-audit", counted:, them: count == 1 ? "it" : "one")
      end

      #: (String, Integer) -> String
      def asked(counted, count)
        Prompts.text("start-a-session/hand-the-first-audit-to-a-subagent",
                     counted:, them: count == 1 ? "it" : "them",
                     command: @invocation.in_project("show-first-audit-brief"))
      end
    end
  end
end

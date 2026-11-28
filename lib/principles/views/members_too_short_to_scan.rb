# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What list-member-problems adds, while requests are logged, for each member too short to find in a logged
    # request: it lists each under too_short_to_scan, and its next_action asks for the move that widens each, after
    # every other action, since the member's own text is as fresh as before.
    class MembersTooShortToScan
      # members is each such member by its principle, id and the move-member options that widen it, placeholders
      # left to fill; invocation names the commands.
      #: (Invocation, Array[Hash[String, String]]) -> void
      def initialize(invocation, members)
        @invocation = invocation
        @members = members
        freeze
      end

      # report, list-member-problems' result whose next_action names a command as names_a_command says, with these
      # members added, and whether its next_action names a command now.
      #: (Hash[String, untyped], bool, nothing_changed: String) -> [Hash[String, untyped], bool]
      def added_to(report, names_a_command, nothing_changed:)
        return [report, names_a_command] if @members.empty?

        action = report.fetch("next_action")
        earlier = action == nothing_changed ? [] : [action]
        [report.merge("too_short_to_scan" => @members.map { it.slice("principle", "id") },
                      "next_action" => [*earlier, *@members.map { widen(it) }].join("\n")), true]
      end

      private

      # The line asking to widen member, with the move that does it.
      #: (Hash[String, String]) -> String
      def widen(member)
        principle = member.fetch("principle")
        id = member.fetch("id")
        "#{id} of #{principle} has no line long enough to find in a logged request, so the scan cannot show " \
          "whether it reached the agent; widen it to take in a longer line: " \
          "#{@invocation.in_project("move-member", principle, id, usage: member.fetch("move"))}"
      end
    end
  end
end

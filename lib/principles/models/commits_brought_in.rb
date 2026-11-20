# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The commits one move of HEAD brought in, by abbreviated id, as the after-commit hook asks about them: one
    # for a commit or an amend, a lane for a fast-forward, the rewritten commits for a rebase. git chooses how long an
    # abbreviated id is, so two name the same commit when one starts with the other (review R4).
    class CommitsBroughtIn
      #: (Array[String]) -> void
      def initialize(commits)
        @commits = commits
        freeze
      end

      # The members, as list-member-problems lists them, whose newest changing commit the move brought in, in order.
      #: (Array[Hash[String, untyped]]) -> Array[Hash[String, untyped]]
      def changed_by(members)
        members.select do |member|
          newest = member.dig("history", "commits", 0, "commit")
          newest && @commits.any? { |commit| commit.start_with?(newest) || newest.start_with?(commit) }
        end
      end
    end
  end
end

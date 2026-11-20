# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # In git, what landed after a completed audit's base commit, as its result prints it: the commits since the base
    # that touched each member the audit changed, by member id, and the base and HEAD when HEAD differs from the base
    # and none touched one. Outside git a completed audit has none, so it is given only in git.
    class LandedSinceBase
      #: (commits_by_member: Hash[String, Array[Hash[String, String]]], ?head_past_base: [String, String]?) -> void
      def initialize(commits_by_member:, head_past_base: nil)
        @commits_by_member = commits_by_member
        @head_past_base = head_past_base
        freeze
      end

      # The fields as printed: commits_since_base, and head_moved_past_base only when head_past_base is given.
      #: () -> Hash[String, untyped]
      def to_h
        printed = { "commits_since_base" => @commits_by_member } #: Hash[String, untyped]
        base, head = @head_past_base
        @head_past_base ? printed.merge("head_moved_past_base" => { "base_commit" => base, "head" => head }) : printed
      end
    end
  end
end

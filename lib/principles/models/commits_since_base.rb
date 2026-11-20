# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # In git, what landed after a completed audit's base commit: for each member the audit changed, the commits
    # since the base that touched it, and HEAD now. When HEAD differs from the base and none touched one, an empty
    # list alone left the agent unsure why an answer on an older base was accepted, so it says so.
    class CommitsSinceBase
      #: (base: String, head: String?, by_member: Hash[String, Array[Hash[String, String]]]) -> void
      def initialize(base:, head:, by_member:)
        @base = base
        @head = head
        @by_member = by_member
        freeze
      end

      # The commits since the base that touched each member the audit changed, by member id.
      #: Hash[String, Array[Hash[String, String]]]
      attr_reader :by_member

      # The base and HEAD, when HEAD differs from the base and no commit since the base touched a member the audit
      # changed; nil otherwise.
      #: () -> [String, String]?
      def head_past_base
        head = @head
        [@base, head] unless head.nil? || head == @base || @by_member.values.any?(&:any?)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One member by its id, with its state now as list-member-problems reports it, which a completed audit names for
    # another principle sharing a file its fixes changed.
    class MemberState
      # The states that mean a member's reference is broken, so an audit would refuse it. unreadable_map is a map's
      # state, which MemberProblems#broken reads over its entries; no MemberState holds it, since a map that cannot be
      # read has no members to name.
      BROKEN = %w[locator_lost unavailable unreadable_map].freeze #: Array[String]

      #: (String, String) -> void
      def initialize(id, state)
        @id = id
        @state = state
        freeze
      end

      # Whether its own text changed or its reference broke, so the principle it belongs to needs auditing again.
      #: () -> bool
      def changed_or_broken? = @state == "changed" || broken?

      # Whether its reference is broken, so an audit would refuse it.
      #: () -> bool
      def broken? = BROKEN.include?(@state)

      # The member as printed: its id and state.
      #: () -> Hash[String, String]
      def to_h = { "id" => @id, "state" => @state }
    end
  end
end

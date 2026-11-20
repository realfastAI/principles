# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One other principle whose members a completed audit's fixes changed or broke, as its result names it under
    # other_principles_with_changed_members, to re-audit by its id.
    class PrincipleWithChangedMembers
      #: (principle_id: String, members: Array[Hash[String, untyped]]) -> void
      def initialize(principle_id:, members:)
        @principle_id = principle_id
        @members = members
        freeze
      end

      # The principle to re-audit.
      #: String
      attr_reader :principle_id

      # The fields as printed: the principle's id and each changed or broken member, by id with its state.
      #: () -> Hash[String, untyped]
      def to_h = { "principle_id" => @principle_id, "members" => @members }
    end
  end
end

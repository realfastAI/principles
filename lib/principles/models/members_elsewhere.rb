# typed: strict
# frozen_string_literal: true

require_relative "member_elsewhere"
require_relative "open_finding"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The members of other principles' maps sharing a line with one located member, as MembersSharingLines finds
    # them: what each result prints of them under mapped_elsewhere, and whether the agent should check the text
    # where their lines meet.
    class MembersElsewhere
      #: (Array[MemberElsewhere]) -> void
      def initialize(members)
        @members = members
        freeze
      end

      # Each as add-member, show-principle and a full audit's request print it under mapped_elsewhere.
      #: () -> Array[Hash[String, untyped]]
      def shown = @members.map(&:to_h)

      # Whether one of them holds the located member's lines, or lies within them, without either being a whole file.
      #: () -> bool
      def text_check_needed? = @members.any?(&:text_check_needed?)

      # The principles whose maps hold them, each once.
      #: () -> Array[String]
      def principle_ids = @members.map(&:principle_id).uniq

      # Each as a full audit's request prints it, naming the findings left_open_by_principle gives its principle that
      # name it.
      #: (Hash[String, Array[OpenFinding]]) -> Array[Hash[String, untyped]]
      def naming(left_open_by_principle)
        @members.map { |member| member.naming(left_open_by_principle.fetch(member.principle_id, [])) }
      end

      # The findings left_open_by_principle gives their principles that name any of them.
      #: (Hash[String, Array[OpenFinding]]) -> Array[OpenFinding]
      def open_among(left_open_by_principle)
        @members.flat_map { |member| member.open_among(left_open_by_principle.fetch(member.principle_id, [])) }
      end
    end
  end
end

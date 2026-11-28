# typed: strict
# frozen_string_literal: true

module Principles
  module Views
    # The other maps whose member set nearly matches the one a member just joined, which ask the agent AddedMember's
    # scope-or-join question.
    class MemberSetsOverlap
      #: (?Array[Hash[String, untyped]]) -> void
      def initialize(facts = [])
        @facts = facts
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h = @facts.empty? ? {} : { "member_sets_overlap" => @facts }

      #: () -> String
      def note
        return "" if @facts.empty?

        "This map's member set nearly matches another's (member_sets_overlap): by member id, they share at least " \
          "two members and at least two thirds of the members either holds. "
      end

      # Whether it asks AddedMember's scope-or-join question: when a member set nearly matches.
      #: () -> bool
      def asks_scope_or_join? = @facts.any?
    end
  end
end

# typed: strict
# frozen_string_literal: true

module Principles
  module Views
    # The optional consecutive-section facts beside an added member and the question they ask the agent.
    class ConsecutiveSectionsElsewhere
      #: (?Array[Hash[String, untyped]]) -> void
      def initialize(facts = [])
        @facts = facts
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h = @facts.empty? ? {} : { "consecutive_sections_elsewhere" => @facts }

      #: () -> String
      def note
        return "" if @facts.empty?

        "Members of other principles occupy consecutive complete Markdown sections in the same underlying file " \
          "(consecutive_sections_elsewhere). These maps have no completed full audit. " \
          "Do they carry one rule or distinct principles? Location alone does not decide. "
      end
    end
  end
end

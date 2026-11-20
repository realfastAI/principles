# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_fields"
require_relative "answer_place"
require_relative "template_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The recent decision under a principle an assessment answer judges against its members' own words: either why
    # none can be checked, or how one held up with pointers to where it is recorded. The record keeps none of it,
    # but a completed audit asks to commit the files its evidence cites.
    class RecentDecision
      # The placeholder start-audit --as template prints in each field of both forms, so the agent fills one form
      # and leaves the other as printed, which is not giving it.
      PLACEHOLDERS = TemplatePlaceholders.new(
        {
          "unavailable_reason" => "Why no recent decision under this principle can be checked. Leave as printed " \
                                  "to check one in assessment and evidence instead",
          "assessment" => "To check a recent decision: how it held up against the members' own words. Leave as " \
                          "printed when unavailable_reason says why none can be checked",
          "evidence" => "With assessment: pointers to where the decision is recorded, as [{\"path\": ..., " \
                        "\"heading\": ...}]. Leave as printed otherwise"
        }
      ) #: TemplatePlaceholders

      # decision is the answer's recent_decision as given; each field left as its placeholder is not given.
      #: (Hash[String, untyped]) -> void
      def initialize(decision)
        @sent_any = !decision.empty? #: bool
        @decision = PLACEHOLDERS.given(decision) #: Hash[String, untyped]
        freeze
      end

      # Whether the decision as sent gives fields and leaves every one as the template printed it, so gives neither
      # form.
      #: () -> bool
      def left_as_printed? = @sent_any && @decision.empty?

      # Refuses the decision unless it gives a written reason none is available, or a written assessment with
      # evidence that fields locates, and one giving neither form, or both, by naming both.
      #: (AnswerFields) -> void
      def check(fields)
        one_form
        if @decision["unavailable_reason"]
          fields.text(@decision["unavailable_reason"], "recent_decision.unavailable_reason")
        else
          fields.text(@decision["assessment"], "recent_decision.assessment")
          fields.evidence(@decision["evidence"], AnswerPlace.new("/recent_decision/evidence", "Recent decision"))
        end
      end

      # The paths its evidence cites, each once; none when the decision was unavailable.
      #: () -> Array[String]
      def paths
        return [] if @decision["unavailable_reason"]

        @decision.fetch("evidence").map { |item| item.fetch("path") }.uniq
      end

      private

      # Refuses a decision that gives neither form, or both, whichever its fields show.
      #: () -> void
      def one_form
        given = %w[unavailable_reason assessment].count { |field| @decision.key?(field) }
        return if given == 1

        given.zero? ? neither : both
      end

      #: () -> bot
      def both
        raise Error.new("invalid_answer", "recent_decision gives both unavailable_reason and assessment",
                        "Keep one form: to check a decision, leave unavailable_reason as printed or remove it; when " \
                        "none can be checked, do the same with assessment and evidence.")
      end

      #: () -> bot
      def neither
        raise Error.new("invalid_answer", "recent_decision gives neither unavailable_reason nor assessment",
                        "Replace unavailable_reason's placeholder with why no recent decision under this principle " \
                        "can be checked, or replace assessment's and evidence's with how one held up and where it " \
                        "is recorded.")
      end
    end
  end
end

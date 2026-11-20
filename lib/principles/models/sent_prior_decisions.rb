# typed: strict
# frozen_string_literal: true

require_relative "prior_decision_fields"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # An assessment answer's prior_finding_decisions as sent, before each is checked against the finding it decides:
    # a decision still the placeholder start-audit --as template printed is no decision, so the answer's one refusal
    # names it with every other judgement left so.
    class SentPriorDecisions
      # decisions is the answer's prior_finding_decisions as sent, a list.
      #: (Array[untyped]) -> void
      def initialize(decisions)
        @decisions = decisions
        freeze
      end

      # Each decision left as printed, named by the finding it decides, with its pointer.
      #: () -> Hash[String, String]
      def left_as_printed
        @decisions.each_with_index.filter_map do |decision, index|
          next unless decision.is_a?(Hash) && decision["decision"] == PriorDecisionFields::DECISION

          ["Prior finding #{decision["finding_id"]} decision", "/prior_finding_decisions/#{index}/decision"]
        end.to_h
      end
    end
  end
end

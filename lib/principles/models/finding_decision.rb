# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_place"
require_relative "answer_text"
require_relative "recorded_finding"
require_relative "waits_on"
require_relative "write_up_pointer"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One decision an answer to start-audit --open-findings gives on an open finding, between full audits: only the
    # fields that change, each kept beside the finding with when and why. Whether the change is right is the agent's
    # judgement; this tool checks its shape.
    class FindingDecision
      # The actions a decision may leave its finding at: those that keep it open. Closing it judges the problem
      # against the text now, which is a full audit's work.
      OPEN_ACTIONS = %w[deferred accepted].freeze #: Array[String]

      # Each field a decision may give beside its finding_id, with its one-line meaning, which the template of
      # start-audit --open-findings prints at its head in decision_fields, where an agent filling it reads.
      FIELDS = {
        "waits_on" => "One line, on a deferred finding only: whom it now waits on and to decide what. Or null, " \
                      "even on a deferred finding, to drop it.",
        "action" => "deferred or accepted, as when the owner rules; its reason becomes the finding's own.",
        "recorded_at" => "Where its write-up is now, in a committed file: {\"path\": ..., \"heading\": ...}; outside " \
                         "the project, such as an issue: {\"url\": \"https://...\"}; or null.",
        "reason" => "One line saying why, required with any change. A field left out keeps its value; " \
                    "decision_fields may be kept or deleted."
      }.freeze #: Hash[String, String]

      # decision is one entry of the answer's decisions, at place in the answer, on a finding of principle_id's;
      # recorded_at is its new pointer, already located, or nil when it gives none or null.
      #: (Hash[String, untyped], AnswerPlace, principle_id: String, ?recorded_at: WriteUpPointer?) -> void
      def initialize(decision, place, principle_id:, recorded_at: nil)
        @decision = decision
        @place = place
        @principle_id = principle_id
        @recorded_at = recorded_at
        freeze
      end

      # The id of the finding it decides.
      #: () -> String
      def finding_id = @decision.fetch("finding_id")

      # finding with this decision's changes made at at, its action before its wait, which is checked against the
      # action it leaves; or finding itself when it changes nothing.
      #: (RecordedFinding, at: String) -> RecordedFinding
      def applied_to(finding, at:)
        acted = @decision.key?("action") ? finding.acting(open_action, at:, reason:) : finding
        acted = acted.pointed_at(@recorded_at, at:, reason:) if @decision.key?("recorded_at")
        return acted unless @decision.key?("waits_on")

        WaitsOn.new(@decision["waits_on"], action: acted.action).check(code: "invalid_answer",
                                                                       subject: "Finding #{finding_id}")
        acted.waiting_on(@decision["waits_on"], at:, reason:)
      end

      private

      # The action it gives, refused unless it keeps the finding open.
      #: () -> String
      def open_action
        action = @decision.fetch("action")
        return action if OPEN_ACTIONS.include?(action)

        raise @place.refusal(Error.new("invalid_answer",
                                       "action #{action} closes the finding, which only a full audit judges",
                                       "Give deferred or accepted, or run a full audit: " \
                                       "#{Error::EXECUTABLE} start-audit #{@principle_id}"))
      end

      # Why it changes the finding, which the record keeps beside each change.
      #: () -> String
      def reason
        AnswerText.new(@decision["reason"]).required("decision.reason")
      rescue Error => e
        raise @place.child("reason").refusal(e)
      end
    end
  end
end

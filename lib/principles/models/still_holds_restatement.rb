# typed: strict
# frozen_string_literal: true

require_relative "answer_fields"
require_relative "answer_place"
require_relative "answer_text"
require_relative "evidence_replacements"
require_relative "open_finding"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What a decision on a prior finding restates of that finding, which only a still_holds decision may: its
    # problem, which its record may lack, a new pointer to its write-up, the evidence its record lacks
    # and a new place for each kept evidence item no longer found.
    # PriorFindingDecision checks the rest of the decision, and refuses for this through refuse.
    class StillHoldsRestatement
      # finding is the prior finding as its record left it open; place is the decision's place in the answer; refuse
      # raises the decision's refusal for a reason and a repair, or the decision's own repair for nil.
      #: (Hash[String, untyped], OpenFinding, AnswerPlace, refuse: ^(String, String?) -> void) -> void
      def initialize(decision, finding, place, refuse:)
        @decision = decision
        @finding = finding
        @place = place
        @refuse = refuse
        @id = finding.id #: String
        freeze
      end

      # Refuses a restatement on any decision but still_holds, a problem that is not one line, kept evidence it
      # replaces but that is still found or named by no replaces, and a pointer locate cannot resolve.
      #: (^(Locator) -> void) -> void
      def check(locate)
        evidence(locate) if @decision.key?("problem_evidence")
        return if @decision.slice("problem", "recorded_at").empty?

        unless @decision["decision"] == "still_holds"
          @refuse.call("only still_holds may give a problem or recorded_at",
                       "Drop problem and recorded_at from #{@id}'s decision, or decide it still_holds.")
        end
        problem if @decision.key?("problem")
        return unless @decision["recorded_at"]

        AnswerFields.new(locate).write_up_pointer(@decision["recorded_at"], @place.child("recorded_at"))
      end

      private

      # The evidence a still_holds decision may give: a finding whose record keeps none, its evidence, and one
      # whose record keeps it, the new place of each kept item no longer found, which EvidenceReplacements checks, so a
      # decision never rewrites what an audit found. This checks only that each pointer resolves.
      #: (^(Locator) -> void) -> void
      def evidence(locate)
        unless @decision["decision"] == "still_holds"
          @refuse.call("only still_holds may give problem_evidence",
                       "Drop problem_evidence from #{@id}'s decision, or decide it still_holds.")
        end
        place = @place.child("problem_evidence")
        if @finding.evidence_kept?
          return @finding.replacements(@decision["problem_evidence"]).check(locate, @id, place, refuse: @refuse)
        end

        lacking(locate, place)
      end

      # The evidence a decision gives a finding whose record keeps none, which has nothing to replace.
      #: (^(Locator) -> void, AnswerPlace) -> void
      def lacking(locate, place)
        given = @decision["problem_evidence"]
        if given.any? { |entry| entry.key?(EvidenceReplacements::REPLACES) }
          @refuse.call("its record keeps no evidence to replace", "Drop replaces from #{@id}'s problem_evidence.")
        end
        AnswerFields.new(locate).evidence(given, place)
      end

      # The problem its record lacks, or a restatement of the one it states when a term in it was renamed or a fact it
      # names moved, which keeps the finding's id and first_raised_at.
      #: () -> void
      def problem
        @refuse.call("problem must be one line", nil) unless AnswerText.new(@decision["problem"]).one_line?
      end
    end
  end
end

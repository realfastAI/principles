# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "decided_prior_findings"
require_relative "kept_prior_finding"
require_relative "prior_finding_decision"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What the next full audit's decisions, once PriorFindings has checked them, do to each finding the last audit
    # left open: the findings kept, as the record keeps them, the ones closed, and, for each new finding that
    # raises a prior one again, when that one was first raised.
    class PriorFindingOutcomes
      # decisions are the checked decisions, each on the finding it decides.
      #: (Array[PriorFindingDecision]) -> void
      def initialize(decisions)
        @decisions = decisions
        freeze
      end

      # What the decisions do to each finding, which each kept finding answers for itself.
      #: () -> DecidedPriorFindings
      def decided
        holding = of(["still_holds"]).map(&:kept)
        DecidedPriorFindings.new(
          { "kept" => holding.map(&:to_h), "closed" => of(PriorFindingDecision::CLOSING).map(&:closed),
            "inherited" => first_raised(of(["raised_again"])),
            "deferrals_raised_again" => deferrals(of(["raised_again"])), **changed(holding) }
        )
      end

      private

      # What the still_holds decisions changed of the findings they kept, which the completed result names.
      #: (Array[KeptPriorFinding]) -> Hash[String, Array[Hash[String, untyped]]]
      def changed(holding)
        { "dropped" => holding.filter_map(&:dropped_write_up),
          "waits_on_dropped" => holding.filter_map(&:waits_on_dropped),
          "evidence_replaced" => holding.flat_map(&:swaps),
          "problems_restated" => holding.filter_map(&:problem_restated) }
      end

      #: (Array[String]) -> Array[PriorFindingDecision]
      def of(kinds) = @decisions.select { |decision| kinds.include?(decision.kind) }

      # When each finding raised again was first raised, by the id of the new finding it became. Two raised as one
      # new finding are refused, since only one first_raised_at can pass on.
      #: (Array[PriorFindingDecision]) -> Hash[String, String?]
      def first_raised(raised)
        raised.group_by(&:raised_as).to_h do |as, same|
          raised_once(as, same.map { |decision| decision.finding.id })
          [as, same.fetch(0).finding.first_raised_at]
        end
      end

      # Where each deferral raised again was written up and whom it waited on, by the id of the new finding it became,
      # so that finding's correction starts from them rather than from nothing.
      #: (Array[PriorFindingDecision]) -> Hash[String, Hash[String, untyped]]
      def deferrals(raised)
        raised.select { |decision| decision.finding.action == "deferred" }.to_h do |decision|
          [decision.raised_as, { "recorded_at" => decision.finding.recorded_at&.to_h,
                                 "waits_on" => decision.finding.waits_on }]
        end
      end

      #: (String, Array[String]) -> void
      def raised_once(as, ids)
        return if ids.one?

        raise Error.new("invalid_decision", "#{ids.join(", ")} are raised again as one new finding, #{as}",
                        "Raise one again as #{as} and close the others as withdrawn, with a reason naming #{as}, " \
                        "or raise each as its own new finding.")
      end
    end
  end
end

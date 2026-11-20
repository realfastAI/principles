# typed: strict
# frozen_string_literal: true

require_relative "first_raised_claim"
require_relative "principle_members"
require_relative "open_finding"
require_relative "waits_on"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A prior finding a still_holds decision kept: the finding as the next record keeps it, and what the decision
    # dropped or replaced of it, which the completed result names so a change not meant can be seen and put back.
    class KeptPriorFinding
      # decision is the checked still_holds decision on finding, the prior finding as its record left it open; members
      # are the map's members now, under whose ids it is recorded.
      #: (Hash[String, untyped], OpenFinding, PrincipleMembers) -> void
      def initialize(decision, finding, members)
        @decision = decision
        @finding = finding
        @record = record(members) #: Hash[String, untyped]
        freeze
      end

      # The finding as the record keeps it, with any problem, pointer, or action and its reason, its decision gave,
      # and any earlier first_raised_at it claimed with the commit it cited; a null pointer drops the one
      # it had. Its evidence is as OpenFinding#evidence_after says, from its own state rather than as the request
      # printed it.
      #: () -> Hash[String, untyped]
      def to_h = @record

      # The pointer it had that its decision dropped with a null recorded_at, or nil when it dropped none.
      #: () -> Hash[String, untyped]?
      def dropped_write_up
        had = @finding.recorded_at
        return unless had && @decision.key?("recorded_at") && @decision["recorded_at"].nil?

        { "finding_id" => @finding.id, "recorded_at" => had.to_h }
      end

      # What it waited on that its decision dropped, with null or by accepting it, or nil when it dropped nothing.
      #: () -> Hash[String, untyped]?
      def waits_on_dropped
        return if @finding.without_waits_on? || @record.key?("waits_on")

        { "finding_id" => @finding.id, **@finding.waiting }
      end

      # The problem its decision restated, as it was and is now, or nil when it restated none.
      #: () -> Hash[String, String]?
      def problem_restated = @finding.restated(@decision["problem"])

      # Each kept evidence item its decision gave a new place, as it was and is now.
      #: () -> Array[Hash[String, untyped]]
      def swaps = @finding.replacements(@decision["problem_evidence"]).swaps(@finding.id)

      private

      #: (PrincipleMembers) -> Hash[String, untyped]
      def record(members)
        kept = @finding.kept_against(members)
                       .merge(@decision.slice("problem", "action", "reason", "recorded_at", *FirstRaisedClaim::FIELDS),
                              { "evidence" => @finding.evidence_after(@decision["problem_evidence"]) }).compact
        kept.merge(waiting_after(kept))
      end

      # What it waits on, and since when, after its decision.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def waiting_after(kept)
        WaitsOn.new(@decision.fetch("waits_on", @finding.waits_on), action: kept.fetch("action"))
               .kept_over(@finding.waiting)
      end
    end
  end
end

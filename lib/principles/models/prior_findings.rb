# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "audit_record"
require_relative "decided_prior_findings"
require_relative "prior_finding_outcomes"
require_relative "prior_finding_decision"
require_relative "member"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The findings the last completed audit deferred or accepted, which the next full audit must decide one by
    # one: each still holds, was resolved, was withdrawn, or is raised again as a new finding. This tool
    # lists them and checks the decisions; whether a finding still holds is the agent's judgement.
    class PriorFindings
      # record is the last audit's record, or nil; members are the map's members now, and now each one's hash.
      #: (record: AuditRecord?, members: PrincipleMembers, now: Hash[String, String]) -> void
      def initialize(record:, members:, now:)
        @record = record
        @left_open = record&.left_open || [] #: Array[OpenFinding]
        @members = members
        @now = now
        freeze
      end

      # Each prior finding as the next audit's request lists it, under its members' ids now, with whether each
      # member changed since that audit.
      #: () -> Array[Hash[String, untyped]]
      def listed
        @left_open.map { |finding| finding.for_next_audit_against(@members, @now) }
      end

      # Each prior finding as the request shows it: as listed, and with a last_audited_commit, each evidence item with
      # what since says of it now against that commit. The request id digests listed, so these facts never
      # make an answer stale.
      #: () { (EvidenceItem, String) -> Hash[String, bool] } -> Array[Hash[String, untyped]]
      def shown(&since)
        base = last_audited_commit or return listed

        @left_open.map { |finding| finding.for_next_audit_against(@members, @now) { |item| since.call(item, base) } }
      end

      # The commit the audit that left these findings open, raising or keeping each, was based on: what each evidence
      # item's text is compared at. nil outside git, or with no record. The record AuditRecord#left_open reads
      # them from gives it, so the two cannot disagree.
      #: () -> String?
      def last_audited_commit = @record&.last_completed&.base_commit

      # What the request id digests, so an answer to a request made before the record changed is stale.
      #: () -> Array[Hash[String, untyped]]
      def digested
        listed.map { |finding| finding.slice("finding_id", "member_ids", "problem", "action", "first_raised_at") }
      end

      # The decisions, checked against the listed findings and this audit's new findings. locate checks that a
      # new recorded_at resolves, as a deferral's is checked; records read the record a claim of an earlier
      # first_raised_at cites.
      #: (untyped, Array[untyped], ?records: AuditRecords?) { (Locator) -> void } -> DecidedPriorFindings
      def decided(decisions, findings, records: nil, &locate)
        new_ids = findings.map { |finding| finding.fetch("id") }
        decisions = checked(complete(decisions, left_open_by_id.keys), new_ids, locate, records)
        PriorFindingOutcomes.new(decisions).decided.tap { it.distinct_from(new_ids) }
      end

      private

      # The decisions, each on the finding it decides, once checked against it and this audit's new findings.
      #: (Array[Hash[String, untyped]], Array[String], ^(Locator) -> void, AuditRecords?)
      #|  -> Array[PriorFindingDecision]
      def checked(decisions, new_ids, locate, records)
        open = left_open_by_id
        decisions.each_with_index.map do |each, index|
          decision = PriorFindingDecision.new(each, open.fetch(each["finding_id"]), new_ids,
                                              at: "/prior_finding_decisions/#{index}", members: @members)
          check(decision, locate, records)
          decision
        end
      end

      # Refuses decision unless it is sound for the finding it decides, given this audit's new findings, and any
      # earlier first_raised_at it claims is borne out by the record it cites, which records read.
      #: (PriorFindingDecision, ^(Locator) -> void, AuditRecords?) -> void
      def check(decision, locate, records)
        decision.check(locate)
        decision.first_raised_claim.check(records, principle_id)
      end

      # The principle whose record left the prior findings open; none is decided without one.
      #: () -> String
      def principle_id = @record ? @record.principle_id : ""

      #: () -> Hash[String, OpenFinding]
      def left_open_by_id = @left_open.to_h { |finding| [finding.id, finding] }

      #: (untyped, Array[String]) -> Array[Hash[String, untyped]]
      def complete(decisions, expected)
        decisions = [] unless decisions.is_a?(Array)
        decided = decisions.map { |decision| decision.is_a?(Hash) ? decision["finding_id"] : nil }
        return decisions if decided.sort == expected.sort

        raise Error.new("incomplete_prior_findings", "Decide each prior finding exactly once: #{expected.join(", ")}",
                        "Give prior_finding_decisions one {finding_id, decision} for each prior finding the request " \
                        "lists, with decision still_holds, resolved, withdrawn or raised_again.")
      end
    end
  end
end

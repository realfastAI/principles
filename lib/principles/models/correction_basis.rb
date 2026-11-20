# typed: strict
# frozen_string_literal: true

require_relative "request_id"
require_relative "decided_prior_findings"
require_relative "audit_start"
require_relative "last_completed_revision"
require_relative "recorded_finding"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # What a correction request depends on, which it prints as its basis and the agent hands back with the answer:
    # the base commit, the map's version, each finding's members and problem, what the assessment reported beyond its
    # findings, as AssessmentReport carries it for the completed record to keep, and the decisions on prior findings,
    # which travel to completion as those do. It also carries the last completed record's revision, so a
    # correction is refused once that record changed.
    class CorrectionBasis
      # The basis printed for a correction of findings, assessed from start: its base, its map's version, the digest of
      # the assessment the open record keeps, and what else of the assessment's report AssessmentReport carries in a
      # basis; revision is the last completed record's.
      #: (AuditStart, findings: Array[untyped], revision: String?, open_record: AuditRecord,
      #|  ?prior: DecidedPriorFindings) -> CorrectionBasis
      def self.printed(start, findings:, revision:, open_record:, prior: DecidedPriorFindings::NONE)
        basis = { "base_commit" => start.base, "map_version" => start.map_version,
                  "last_completed_revision" => revision,
                  "findings" => findings.map { |finding| finding.slice(*RecordedFinding::RAISED_FIELDS) },
                  "assessment_report_sha256" => open_record.assessment_digest }
        basis = basis.merge(start.reported.basis_fields)
        new(prior.none? ? basis : basis.merge("prior_findings" => prior.to_h))
      end

      #: (untyped) -> void
      def initialize(fields)
        @fields = fields #: untyped
        freeze
      end

      #: () -> untyped
      def to_h = @fields

      # The commit the audit it corrects began from, or nil outside git.
      #: () -> String?
      def base_commit = @fields.fetch("base_commit")

      # The version of the map the audit it corrects began from.
      #: () -> String
      def map_version = @fields.fetch("map_version")

      # The findings it asks the correction to dispose of, each with the fields RecordedFinding::RAISED_FIELDS names.
      #: () -> Array[Hash[String, untyped]]
      def findings = @fields.fetch("findings")

      # The decisions on prior findings it carries to completion, or none.
      #: () -> DecidedPriorFindings
      def prior_decided
        decided = @fields["prior_findings"]
        decided ? DecidedPriorFindings.new(decided) : DecidedPriorFindings::NONE
      end

      # The id of the correction request of principle_id for this basis, with each member's hash when the audit began.
      #: (String, Hash[String, String]) -> RequestId
      def request_id(principle_id, before)
        RequestId.handing_back(principle_id: principle_id, phase: "correction", handed: @fields, parts: [before])
      end

      # Whether record is the open record this basis was printed with, its assessment unchanged since.
      #: (AuditRecord?) -> bool
      def printed_with?(record)
        !record.nil? && !record.completed? && record.assessment_digest == @fields["assessment_report_sha256"]
      end

      # The last completed record's revision when the request was printed, which refuses a correction once that
      # record changed.
      #: () -> LastCompletedRevision
      def printed_after = LastCompletedRevision.new(@fields["last_completed_revision"])
    end
  end
end

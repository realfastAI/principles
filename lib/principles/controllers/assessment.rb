# typed: strict
# frozen_string_literal: true

require "time"
require_relative "answer_phase"
require_relative "../models/assessment_left_as_printed"
require_relative "../models/audit"
require_relative "../models/request_id"
require_relative "../models/unchecked_members"
require_relative "../models/uncommitted_files"
require_relative "audit_completion"
require_relative "full_audit_request"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # A full audit's assessment, which submit-answer and show-answer-check hand over: this tool checks the request
    # it answers and each member's assessment, then completes an audit with no findings or asks for the correction
    # of its findings.
    class Assessment < AnswerPhase
      # The result of answering an assessment request, which checked_request found unchanged, with the prior findings
      # it listed, and the record change it makes, not yet written.
      # @override
      #: (Models::SubmittedAnswer) -> [untyped, Array[Models::AuditRecord]]
      def answered(submitted)
        response = submitted.response
        prior = submitted.prior_findings
        audit = audit_now(submitted.request_id.principle_id)
        basis = Models::AssessmentBasis.new(response.fetch("basis"))
        judged_against = record_judged_against(audit)
        basis.printed_after.refusing_stale_first(audit.id, @audit_records.find(audit.id)) do
          judged_assessment(response, audit, prior, judged_against, basis)
        end
      end

      # The prior findings the request an answer's head names listed, refused when that request, given the head's
      # basis, no longer matches the project, before the rest of the answer's shape is read: checked here alone, since
      # its template prints placeholders this release's schema could otherwise refuse first.
      #: (Models::RequestId, Hash[String, untyped]) -> Models::PriorFindings
      def checked_request(request_id, head)
        audit = audit_now(request_id.principle_id)
        basis = Models::AssessmentBasis.new(head.fetch("basis"))
        prior = audit.check_assessment_request(request_id, basis: basis, committed: committed(basis.base, audit.map),
                                                           record: @audit_records.find(audit.id),
                                                           loads: loads_to_check(audit))
        principle_history(audit.id).confirm_current_id_since(basis.base)
        prior
      end

      # The refusals an answer meets before its shape: first a check_result on a member with no check, which the
      # shape would refuse as lacking its command, then any phase's, whose template is read first, as before,
      # then a judgement left as its template printed it, named with the shape's problems, so one refusal names both.
      #: (Models::RequestId) -> Array[Models::RefusalBeforeShape]
      def before_shape(request_id)
        any_phase = super
        [Models::UncheckedMembers.new(@principles.find(request_id.principle_id).members), *any_phase,
         Models::AssessmentLeftAsPrinted.new]
      end

      # Each member the answer carries forward whose kept assessment names a prior finding it decides other than
      # still_holds, from the record the answer is judged against.
      # @override
      #: (Models::SubmittedAnswer) -> Array[Hash[String, untyped]]
      def carried_naming_decided(submitted)
        audit = audit_now(submitted.request_id.principle_id)
        record_judged_against(audit).carried.naming_decided(submitted.response)
      end

      # Each prior finding whose write-up pointer the answer drops with null, with the pointer it had, as the
      # decisions on the prior findings, once checked, say.
      # @override
      #: (Models::SubmittedAnswer) -> Array[Hash[String, untyped]]
      def pointers_dropped(submitted)
        response = submitted.response
        decided = submitted.prior_findings.decided(response["prior_finding_decisions"], response.fetch("findings", []),
                                                   records: @audit_records) { |locator| snapshot(locator) }
        decided.changed.fetch("pointers_dropped")
      end

      private

      # The placeholders a full audit's template printed, as start-audit --as template prints it now.
      #: (Models::RequestId) -> Hash[String, untyped]?
      def printed_placeholders(request_id)
        handed(FullAuditRequest, principle_id: request_id.principle_id).to_fill
      rescue Error => e
        # Template construction keeps the start guard, but this caller already has an answer to retry.
        raise unless e.payload.fetch("code") == "uncommitted_files"

        raise e.including("repair" => Models::UncommittedFiles::ASSESSMENT_REPAIR)
      end

      # The assessment's fields and its decisions on the prior findings checked, then the audit completed or its
      # correction asked for.
      #: (untyped, Models::Audit, Models::PriorFindings, Models::RecordJudgedAgainst, Models::AssessmentBasis)
      #|  -> [untyped, Array[Models::AuditRecord]]
      def judged_assessment(response, audit, prior, judged_against, basis)
        assessed = audit.assessment(response, judged_against, Time.now.utc.iso8601) do |locator|
          snapshot(locator)
        end
        findings = assessed.findings
        decided = prior.decided(response["prior_finding_decisions"], findings, records: @audit_records) do |locator|
          snapshot(locator)
        end
        correction(audit.assessed_start(basis.base, assessed, grounds(audit)), audit, findings, decided, basis)
      end

      # Completes an audit with no findings. Otherwise asks the agent to correct them. Each is refused once the last
      # completed record changed after the assessment's request was printed, the completion unless it writes
      # nothing.
      #: (Models::AuditStart, Models::Audit, Array[untyped], Models::DecidedPriorFindings, Models::AssessmentBasis)
      #|  -> [untyped, Array[Models::AuditRecord]]
      def correction(start, audit, findings, decided, assessed)
        if findings.empty?
          return handed(AuditCompletion, replacing: assessed.printed_after).completed(start, audit, [], [], decided)
        end

        correction_request(start, audit, findings, decided, assessed)
      end

      # The correction request for findings, and the open record that keeps the assessment, whose digest its basis
      # carries in place of the assessment, so the correction reads it back from the record, and keeps the
      # correction's request_id and basis, so show-open-correction prints it again.
      # It is refused before it is printed once the last completed record changed, so no fix is made for an audit
      # that cannot complete. The check results travel in the record, so the completed record keeps them.
      #: (Models::AuditStart, Models::Audit, Array[untyped], Models::DecidedPriorFindings, Models::AssessmentBasis)
      #|  -> [untyped, Array[Models::AuditRecord]]
      def correction_request(start, audit, findings, decided, assessed)
        assessed.printed_after.confirm_unchanged(audit.id, @audit_records.find(audit.id))
        record = open_record(start, audit, findings)
        basis = Models::CorrectionBasis.printed(start, findings: findings, prior: decided, revision: assessed.revision,
                                                       open_record: record)
        request = request_to_correct(basis, audit, findings)
        [request, @audit_records.changes(record.correcting(request.request_id, basis.to_h))]
      end

      # The correction request for findings, answered under an id that digests its basis and the members now.
      #: (Models::CorrectionBasis, Models::Audit, Array[untyped]) -> Views::CorrectionRequest
      def request_to_correct(basis, audit, findings)
        head = Views::AnswerHead.new(request_id: basis.request_id(audit.id, audit.now).to_s, basis: basis.to_h)
        Views::CorrectionRequest.new(head: head, principle_id: audit.id, findings: findings,
                                     placeholders: Models::DispositionPlaceholders::TEMPLATE_PLACEHOLDERS)
      end

      # The open record that keeps the assessment, and outside git what the audit began from, and the last completed
      # record, so a restarted audit still lists its prior findings, in git as outside it.
      #: (Models::AuditStart, Models::Audit, Array[untyped]) -> Models::AuditRecord
      def open_record(start, audit, findings)
        last = @audit_records.find(audit.id)&.last_completed
        raised = findings.map { |finding| finding.slice(*Models::RecordedFinding::RAISED_FIELDS) }
        handed(AuditCompletion).record(start, raised, "open", audit.now, last)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "time"
require_relative "answer_phase"
require_relative "../models/finding_write_ups"
require_relative "../models/open_findings_decision"
require_relative "../views/answered_request"
require_relative "../views/open_findings_decision_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # A decision on a principle's open findings between full audits: start-audit ID --open-findings lists each open
    # finding with where its write-up is now, and submit-answer makes each change the answer gives in the last
    # completed record, keeping it beside its finding.
    class OpenFindingDecisions < AnswerPhase
      # The request start-audit id --open-findings prints, for a decision on any of the principle's open findings, or
      # with to_fill its answer alone.
      #: (String, to_fill: bool) -> Hash[String, untyped]
      def decide(id, to_fill:)
        naming_the_executable do
          record = @audit_records.find(id)
          decisions = decisions_of(id, record)
          request = view.decision_request(request_id: decisions.request_id.to_s, principle_id: id,
                                          revision: decisions.revision, fields: Models::FindingDecision::FIELDS,
                                          findings: Models::FindingWriteUps.of(@project, [record].compact).listed)
          to_fill ? request.fetch("response_template") : request.merge("wrote" => [])
        end
      end

      # The result of answering, and the record it changes, not yet written, which is refused once the last completed
      # record changed after the request was printed, unless it writes nothing.
      # @override
      #: (Models::SubmittedAnswer) -> [Views::AnsweredRequest, Array[Models::AuditRecord]]
      def answered(submitted)
        id = submitted.request_id.principle_id
        decisions = decisions_of(id, @audit_records.find(id))
        decided = decisions.decided(submitted.response, at: Time.now.utc.iso8601) { |locator| snapshot(locator) }
        changes = decisions.confirmed_writable(decided, submitted.response, records: @audit_records)
        [Views::AnsweredRequest.new(result(id, decisions.changed_ids(decided))), changes]
      end

      private

      # The decision on principle id's open findings, as its record holds them.
      #: (String, Models::AuditRecord?) -> Models::OpenFindingsDecision
      def decisions_of(id, record)
        Models::OpenFindingsDecision.new(principle_id: id, record: record, history: @history)
      end

      # The result naming the findings of principle id that the decisions changed, the record to commit, and each
      # other principle's open finding whose write-up cannot be found (T16).
      #: (String, Array[String]) -> Hash[String, untyped]
      def result(id, changed)
        others = @audit_records.of(@principles.ids - [id])
        view.decided(principle_id: id, file: @audit_records.file(id), changed:,
                     not_found_elsewhere: Models::FindingWriteUps.of(@project, others).not_found)
      end

      #: () -> Views::OpenFindingsDecisionResult
      def view = Views::OpenFindingsDecisionResult.new(invocation)
    end
  end
end

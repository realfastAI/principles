# typed: strict
# frozen_string_literal: true

require "time"
require_relative "answer_phase"
require_relative "../models/finding_write_ups"
require_relative "../models/repoint"
require_relative "../views/repoint_result"

require_relative "../views/answered_request"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # A repoint of a principle's open findings' write-ups: start-audit ID --write-ups lists each open finding
    # with where its write-up is now, and submit-answer points the recorded_at the agent gives in the audit record.
    class Repoint < AnswerPhase
      # The request for principle id's open findings.
      #: (String) -> Hash[String, untyped]
      def start(id)
        naming_the_executable do
          record = @audit_records.find(id)
          repoint = repoint_of(id, record)
          findings = Models::FindingWriteUps.of(@project, [record].compact).listed
          view.request(request_id: repoint.request_id.to_s, principle_id: id, revision: repoint.revision,
                       findings: findings).merge("wrote" => [])
        end
      end

      # The result of answering, and the record it changes, not yet written, which the repoint refuses once the last
      # completed record changed after the request was printed, unless it writes nothing.
      # @override
      #: (Models::SubmittedAnswer) -> [Views::AnsweredRequest, Array[Models::AuditRecord]]
      def answered(submitted)
        id = submitted.request_id.principle_id
        response = submitted.response
        repoint = repoint_of(id, @audit_records.find(id))
        repointed, changes = repoint.writable(response, records: @audit_records, at: Time.now.utc.iso8601) do |locator|
          snapshot(locator)
        end
        [Views::AnsweredRequest.new(view.repointed(principle_id: id, file: @audit_records.file(id),
                                                   outcome: outcome(repoint, repointed))), changes]
      end

      private

      # The repoint of principle id's open findings, as its record holds them.
      #: (String, Models::AuditRecord?) -> Models::Repoint
      def repoint_of(id, record) = Models::Repoint.new(principle_id: id, record: record, history: @history)

      # What the repoint did, and each other principle's open finding whose write-up cannot be found (T16).
      #: (Models::Repoint, Models::AuditRecord) -> Views::RepointResult::Outcome
      def outcome(repoint, repointed)
        others = @audit_records.of(@principles.ids - [repointed.principle_id])
        Views::RepointResult::Outcome.new(repointed: repoint.moved_ids(repointed),
                                          unchanged: repoint.unchanged_ids(repointed),
                                          not_found_elsewhere: Models::FindingWriteUps.of(@project, others).not_found)
      end

      #: () -> Views::RepointResult
      def view
        Views::RepointResult.new(invocation)
      end
    end
  end
end

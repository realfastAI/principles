# typed: strict
# frozen_string_literal: true

require_relative "answer_phase"
require_relative "../models/audit"
require_relative "../models/correction_answer"
require_relative "../models/declared_map_changes"
require_relative "../models/finding_write_ups"
require_relative "../models/request_id"
require_relative "../views/correction_request"
require_relative "audit_completion"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # A full audit's correction, which submit-answer and show-answer-check hand over: this tool checks each
    # disposition, and any members moved or whose role or check a fix changed, against the map and hashes the
    # audit began from, and completes the audit.
    class Correction < AnswerPhase
      # The result of answering a correction request, and the record change it makes, not yet written. A refused
      # answer to a request printed before the record changed is refused as stale, so the agent starts again rather
      # than repairing it.
      # @override
      #: (Models::SubmittedAnswer) -> [untyped, Array[Models::AuditRecord]]
      def answered(submitted)
        request_id = submitted.request_id
        response = submitted.response
        audit = audit_now(request_id.principle_id)
        Models::CorrectionBasis.new(response.fetch("basis")).printed_after
                               .refusing_stale_first(audit.id, @audit_records.find(audit.id)) do
          judged_correction(request_id, response, audit)
        end
      end

      # What each map entry a fix in the answer claims changed, from the map its audit started from and its map now;
      # the audit is built and the base map read only when a fix claims one.
      # @override
      #: (Models::SubmittedAnswer) -> Array[Hash[String, untyped]]
      def map_entry_changes(submitted)
        response = submitted.response
        changes = Models::DeclaredMapChanges.declared_in(response)
        changes.entry_changes do
          audit = audit_now(submitted.request_id.principle_id)
          [started_from(Models::CorrectionBasis.new(response.fetch("basis")), audit, changes), audit.map]
        end
      end

      # Each finding the completed record leaves deferred with recorded_at null.
      # @override
      #: (Array[Models::AuditRecord]) -> Array[String]
      def deferred_written_up_nowhere(changes)
        Models::FindingWriteUps.of(@project, changes).deferred_written_up_nowhere
      end

      private

      # The placeholders a correction's template printed, its dispositions'.
      #: (Models::RequestId) -> Hash[String, untyped]?
      def printed_placeholders(_request_id) = Models::DispositionPlaceholders::TEMPLATE_PLACEHOLDERS

      # The result of judging a correction answer: its basis, moves and dispositions checked, and the audit completed.
      #: (Models::RequestId, untyped, Models::Audit) -> [untyped, Array[Models::AuditRecord]]
      def judged_correction(request_id, response, audit)
        basis = Models::CorrectionBasis.new(response.fetch("basis"))
        changes = Models::DeclaredMapChanges.declared_in(response)
        moves = Models::MemberMoves.new(response["moved_members"])
        before = moves.hashes(confirmed_start(request_id, basis, audit, changes))
        findings = moves.findings(basis.findings)
        start = resumed(audit, basis, before, moves)
        completion(changes, basis, audit).completed(start, audit, dispositions(response, findings, start, audit),
                                                    findings, basis.prior_decided.moved(moves))
      end

      # What the audit a correction resumes began from, its assessment read back from the record it left.
      #: (Models::Audit, Models::CorrectionBasis, Hash[String, String], Models::MemberMoves) -> Models::AuditStart
      def resumed(audit, basis, before, moves) = audit.resumed(basis, before, moves, @audit_records.find(audit.id))

      # The packaged answer guide, which the correction request prints, is the one owner of its samples, the text
      # the agent saw, but for the deferred sample's reason, which is the template's reason placeholder that
      # Models::Disposition owns. Its sample for each action is handed to the model, which refuses a field given back
      # as its sample. Should the tool be upgraded between request and answer, that answer is checked only
      # against the new guide's samples.
      #: (untyped, Array[untyped], Models::AuditStart, Models::Audit) -> Array[Models::Disposition]
      def dispositions(response, findings, start, audit)
        samples = Views::CorrectionRequest.answer_guide(Models::DispositionPlaceholders::PLACEHOLDERS.fetch("reason"))
                                          .fetch("disposition")
        start.check_plugin_members_unchanged(now: audit.now)
        Models::CorrectionAnswer.new(response, findings, samples:) { |locator| snapshot(locator) }
                                .dispositions(changed: start.changed(now: audit.now))
      end

      # The map the audit began from, read from the base commit when the answer declares changes to the map.
      #: (Models::CorrectionBasis, Models::Audit, Models::DeclaredMapChanges) -> Models::Principle
      def started_from(basis, audit, changes)
        audit.map_started_from(basis, changes, map_file: @principles.file(audit.id)) do |base|
          committed_map(base, audit.id)
        end
      end

      # The map id as the base commit holds it.
      #: (String, String) -> Models::Principle
      def committed_map(base, id)
        principle_history(id).map_at(base)
      end

      # Each member's hash when the audit began, checked against the request id, from the map it started from, after
      # the declared changes are checked against that map.
      #: (Models::RequestId, Models::CorrectionBasis, Models::Audit, Models::DeclaredMapChanges) -> Hash[String, String]
      def confirmed_start(request_id, basis, audit, changes)
        base = basis.base_commit
        found = hashes_started_with(base, started_from(basis, audit, changes))
        checked = audit.confirmed_start(request_id, basis, found)
        principle_history(audit.id).confirm_current_id_since(base)
        checked
      end

      # Each member's hash when the audit of map began: at the base commit in git, beside each plugin member's from
      # the open record, since no commit holds a plugin's file; or all from the open record outside git; nil when
      # they cannot be found.
      #: (String?, Models::Principle) -> Hash[String, String]?
      def hashes_started_with(base, map)
        record = @audit_records.find(map.id)
        return record&.base_members unless base

        committed(base, map)&.merge(record&.members&.plugin_hashes(map.members) || {})
      end

      # The completion of a correction, which read its assessment back from the audit's record: the open one or, for
      # an identical retry, the completed one.
      #: (Models::DeclaredMapChanges, Models::CorrectionBasis, Models::Audit) -> AuditCompletion
      def completion(map_changes, basis, audit)
        handed(AuditCompletion, map_changes: map_changes, replacing: basis.printed_after,
                                read_back_from: @audit_records.find(audit.id))
      end
    end
  end
end

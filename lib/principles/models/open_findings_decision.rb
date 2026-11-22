# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_fields"
require_relative "answer_place"
require_relative "audit_record"
require_relative "audit_records"
require_relative "finding_decision"
require_relative "last_completed_revision"
require_relative "project_history"
require_relative "request_id"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A decision on a principle's open findings between full audits: the agent gives, for each finding it names,
    # only what changes of its wait, action or write-up, and the last completed record keeps each change beside it,
    # with the old value, when and why. Whether the change is right is the agent's judgement.
    class OpenFindingsDecision
      # The phase of start-audit --open-findings, which decides a finding's wait, action or write-up.
      DECIDING = "deciding"

      # record is the principle's audit record now; history says whether a new pointer's file is committed.
      #: (principle_id: String, record: AuditRecord?, history: ProjectHistory) -> void
      def initialize(principle_id:, record:, history:)
        @principle_id = principle_id
        @record = record
        @history = history
        freeze
      end

      # The request's id, digesting the last completed record's revision it was printed after, so an answer is
      # matched to the record it read.
      #: () -> RequestId
      def request_id = RequestId.for(principle_id: @principle_id, phase: DECIDING, parts: [revision])

      # The completed record's revision, which the request prints and the answer hands back.
      #: () -> String
      def revision = completed.revision

      # The record with each decision an answer to start-audit --open-findings gives applied at at, once each names a
      # different open finding and each new recorded_at is located by the block, in a committed file; a decision that
      # changes no field leaves its finding as it is.
      #: (untyped, at: String) { (Locator) -> void } -> AuditRecord
      def decided(response, at:, &locate)
        fields = AnswerFields.new(locate)
        decisions = response.fetch("decisions")
        each_open_once(decisions.map { |decision| decision.fetch("finding_id") })
        completed.decided(decisions.each_with_index.map { |decision, index| decision_at(decision, index, fields) },
                          at:)
      end

      # The records decided changes among records, not yet written: refused once the record changed after the
      # request, whose revision response quotes back in its basis, was printed, unless it changes none.
      #: (AuditRecord, untyped, records: AuditRecords) -> Array[AuditRecord]
      def confirmed_writable(decided, response, records:)
        changes = records.changes(decided)
        LastCompletedRevision.new(response.dig("basis", "revision")).confirm_writable(@principle_id, @record, changes)
        changes
      end

      # The ids of the completed record's open findings that decided, the record accepted, changes.
      #: (AuditRecord) -> Array[String]
      def changed_ids(decided)
        before = completed.left_open.to_h { |finding| [finding.id, finding.listed] }
        decided.left_open.reject { |finding| before[finding.id] == finding.listed }.map(&:id)
      end

      # Refuses unless the principle's record is a completed audit's: an open record outside git keeps the completed
      # one, whose findings its correction will decide, and with none there is nothing to decide.
      #: () -> AuditRecord
      def completed
        record = @record
        return record if record&.completed?

        start = "#{Error::EXECUTABLE} start-audit #{@principle_id}"
        if record
          raise Error.new("cannot_decide_open_findings",
                          "#{@principle_id} has an audit left open, whose correction decides its findings",
                          "Answer that correction, or start the audit again: #{start}")
        end

        raise Error.new("cannot_decide_open_findings", "#{@principle_id} has no completed audit, so no finding is open",
                        "Run a full audit first: #{start}")
      end

      private

      # Refuses ids, the findings an answer's decisions name, when one is not open in the completed record or two
      # name one finding, since either would otherwise read as a success.
      #: (Array[String]) -> void
      def each_open_once(ids)
        open = completed.open_ids
        unknown = ids - open
        unless unknown.empty?
          raise Error.new("unknown_finding", "#{@principle_id}'s last completed audit leaves no finding " \
                                             "#{unknown.join(", ")} open",
                          "Decide only its open findings: #{open.join(", ")}")
        end
        each_once(ids)
      end

      #: (Array[String]) -> void
      def each_once(ids)
        repeated = ids.tally.select { |_, count| count > 1 }.keys
        return if repeated.empty?

        raise Error.new("duplicate_finding", "Decisions name #{repeated.join(", ")} more than once",
                        "Give each finding one decision.")
      end

      # The decision at index, its new recorded_at, when it gives one, located and committed.
      #: (Hash[String, untyped], Integer, AnswerFields) -> FindingDecision
      def decision_at(decision, index, fields)
        place = AnswerPlace.new("/decisions/#{index}", "Finding #{decision["finding_id"]}")
        reference = decision["recorded_at"]
        pointer = fields.write_up_pointer(reference, place.child("recorded_at")) if reference
        @history.refuse_uncommitted_write_up(pointer.path) if pointer
        FindingDecision.new(decision, place, principle_id: @principle_id, recorded_at: pointer)
      end
    end
  end
end

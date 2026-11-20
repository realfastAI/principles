# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_fields"
require_relative "answer_place"
require_relative "audit_record"
require_relative "audit_records"
require_relative "last_completed_revision"
require_relative "project_history"
require_relative "request_id"
require_relative "write_up_repoint"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A repoint of a principle's open findings' write-ups without a full audit: the agent, having checked
    # where a write-up moved to, gives each finding it names a new recorded_at, and the last completed record keeps
    # it, with where it pointed before, when and why. Judging that the new place holds the write-up is the agent's.
    class Repoint
      PHASE = "repointing"

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
      def request_id = RequestId.for(principle_id: @principle_id, phase: PHASE, parts: [revision])

      # The completed record's revision, which the request prints and the answer hands back.
      #: () -> String
      def revision = completed.revision

      # The record with each repoint the answer gives in it, once each names a different open finding and each new
      # pointer is located by the block, in a committed file; a repoint whose recorded_at is null leaves its
      # finding as it is.
      #: (untyped, at: String) { (Locator) -> void } -> AuditRecord
      def accepted(response, at:, &locate)
        fields = AnswerFields.new(locate)
        repoints = response.fetch("repoints")
        each_open_once(repoints.map { |repoint| repoint.fetch("finding_id") })
        given = repoints.each_with_index.select { |repoint, _| repoint["recorded_at"] }
        completed.repointed(given.map { |repoint, index| located(repoint, index, fields) }, at: at)
      end

      # The record accepted from the answer, as accepted gives it, and the records it changes among records, not yet
      # written: refused once the record changed after the request, whose revision the answer quotes back in its basis,
      # was printed, unless it changes none.
      #: (untyped, records: AuditRecords, at: String) { (Locator) -> void } -> [AuditRecord, Array[AuditRecord]]
      def writable(response, records:, at:, &locate)
        repointed = accepted(response, at:, &locate)
        changes = records.changes(repointed)
        LastCompletedRevision.new(response.dig("basis", "revision")).confirm_writable(@principle_id, @record, changes)
        [repointed, changes]
      end

      # The ids of the completed record's open findings that repointed, the record accepted, points elsewhere (T16).
      #: (AuditRecord) -> Array[String]
      def moved_ids(repointed) = repointed.write_ups_moved_since(completed)

      # The ids of the rest, which repointed leaves where they pointed, so a repeat or a skipped finding is seen as one.
      #: (AuditRecord) -> Array[String]
      def unchanged_ids(repointed) = completed.open_ids - moved_ids(repointed)

      # Refuses unless the principle's record is a completed audit's: an open record outside git keeps the completed
      # one, whose findings its correction will decide, and with none there is nothing to repoint.
      #: () -> AuditRecord
      def completed
        record = @record
        return record if record&.completed?

        start = "#{Error::EXECUTABLE} start-audit #{@principle_id}"
        if record
          raise Error.new("cannot_repoint",
                          "#{@principle_id} has an audit left open, whose correction decides its findings",
                          "Answer that correction, or start the audit again: #{start}")
        end

        raise Error.new("cannot_repoint", "#{@principle_id} has no completed audit, so no finding is open",
                        "Run a full audit first: #{start}")
      end

      private

      # Refuses ids, the findings an answer's repoints name, when one is not open in the completed record or two
      # name one finding, since either would otherwise read as a success.
      #: (Array[String]) -> void
      def each_open_once(ids)
        open = completed.open_ids
        unknown = ids - open
        unless unknown.empty?
          raise Error.new("unknown_finding", "#{@principle_id}'s last completed audit leaves no finding " \
                                             "#{unknown.join(", ")} open",
                          "Repoint only its open findings: #{open.join(", ")}")
        end
        each_once(ids)
      end

      #: (Array[String]) -> void
      def each_once(ids)
        repeated = ids.tally.select { |_, count| count > 1 }.keys
        return if repeated.empty?

        raise Error.new("duplicate_finding", "Repoints name #{repeated.join(", ")} more than once",
                        "Give each finding one repoint.")
      end

      # The repoint at index, its recorded_at located and committed, and its reason given.
      #: (Hash[String, untyped], Integer, AnswerFields) -> WriteUpRepoint
      def located(repoint, index, fields)
        place = AnswerPlace.new("/repoints/#{index}", "Finding #{repoint["finding_id"]}")
        pointer = fields.write_up_pointer(repoint["recorded_at"], place.child("recorded_at"))
        @history.refuse_uncommitted_write_up(pointer.path)
        WriteUpRepoint.answered(repoint, pointer, fields, place)
      end
    end
  end
end

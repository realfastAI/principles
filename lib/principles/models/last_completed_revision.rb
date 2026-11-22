# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "audit_record"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The revision of a principle's last completed audit record when a request was printed, or nil when there was
    # none. An assessment's basis and a correction's carry it, so either answer is refused once that record changed,
    # by another audit completing or a member's acknowledgement, rather than replacing it and what it left open.
    class LastCompletedRevision
      #: (String?) -> void
      def initialize(revision)
        @revision = revision
        freeze
      end

      # Refuses an answer of principle_id that would write changes, when record, the record now, changed since the
      # request was printed. An answer that writes nothing, as an identical retry does, is accepted.
      #: (String, AuditRecord?, Array[untyped]) -> void
      def confirm_writable(principle_id, record, changes)
        confirm_unchanged(principle_id, record) unless changes.empty?
      end

      # What the block gives, judging an answer of principle_id; but when the block refuses the answer while record,
      # the record now, changed since the request was printed, the refusal is that the request is stale, so the agent
      # does not repair an answer it must start again. An answer the block refuses is not the identical
      # retry, which passed every check, so the stale refusal always wins over it.
      #: [T] (String, AuditRecord?) { () -> T } -> T
      def refusing_stale_first(principle_id, record, &)
        yield
      rescue Error
        confirm_unchanged(principle_id, record)
        raise
      end

      # Refuses any answer of principle_id when record, the record now, changed since the request was printed.
      #: (String, AuditRecord?) -> void
      def confirm_unchanged(principle_id, record)
        last = record&.last_completed
        return if @revision == last&.revision

        raise Error.new("audit_completed_since_request",
                        "The record of #{principle_id}'s last audit changed after this request was printed: " \
                        "#{what_changed(last)}, and answering it would replace that record and what it left open",
                        "To see what the record now leaves open: " \
                        "#{Error::EXECUTABLE} list-open-findings #{principle_id}\n" \
                        "Then start the audit again and answer the new request: " \
                        "#{Error::EXECUTABLE} start-audit #{principle_id}")
      end

      private

      # What changed the record last: its removal, the newest acknowledgement since its audit, or else the audit.
      # Acknowledgements are dropped when a full audit completes, so any kept is newer than the audit.
      #: (AuditRecord?) -> String
      def what_changed(last)
        return "the record was removed" unless last

        id, at = last.members.latest_acknowledgement
        return "#{id} was acknowledged at #{at}" if id

        "an audit completed at #{last.to_h.fetch("audited_at")}"
      end
    end
  end
end

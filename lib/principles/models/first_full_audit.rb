# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "audit_record"

module Principles
  module Models
    # A principle's first full audit, which one background subagent runs from show-first-audit-brief so the session
    # that starts it spends little of its context on it: its id, and its record, or nil with none.
    class FirstFullAudit
      #: (String, AuditRecord?) -> void
      def initialize(id, record)
        @id = id
        @record = record
        freeze
      end

      # Refuses once a full audit of the principle has completed, its record completed or open on a later audit,
      # since the brief is for a principle no audit has judged yet, and a second subagent would spend an audit's
      # reading for nothing.
      #: () -> void
      def refuse_once_completed
        @record&.last_completed or return

        raise Error.new("first_audit_completed", "A full audit of #{@id} has completed, so its first is done",
                        "To list the principles still awaiting a first full audit, run:\n" \
                        "#{Error::EXECUTABLE} show-first-audit-brief")
      end
    end
  end
end

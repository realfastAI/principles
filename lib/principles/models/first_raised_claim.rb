# typed: strict
# frozen_string_literal: true

require "time"
require_relative "../error"
require_relative "audit_records"
require_relative "open_finding"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A still_holds decision's claim that its finding was first raised earlier than the record says, citing in
    # raised_in the commit whose audit record left it open then. Whether that record's finding is the same
    # finding is the agent's judgement. This tool checks only the facts the claim cites, at that one commit: the
    # record there leaves a finding with the same id deferred or accepted, its audit was made at the claimed time,
    # and that time is earlier than the one stored. It walks no history.
    class FirstRaisedClaim
      FIELDS = %w[first_raised_at raised_in].freeze

      # decision is the agent's decision on finding, the prior finding as its record left it open.
      #: (Hash[String, untyped], OpenFinding) -> void
      def initialize(decision, finding)
        @decision = decision
        @id = finding.id #: String
        @stored = finding.first_raised_at #: String?
        freeze
      end

      # Refuses the claim unless it is whole, on a still_holds decision, and the record of principle_id that records
      # reads at its commit bears it out; a decision that claims nothing passes, and needs no records.
      #: (AuditRecords?, String) -> void
      def check(records, principle_id)
        return if @decision.slice(*FIELDS).empty?

        whole
        records or raise ArgumentError, "a claim on #{@id} is checked only against the audit records"
        borne_out(*read(records, principle_id))
        raise not_earlier unless earlier?
      end

      private

      # Refuses unless version, the record read from path, leaves this finding open from an audit at the claimed time.
      #: (String, AuditRecord) -> void
      def borne_out(path, version)
        open = version.open_findings.find { |finding| finding.fetch("finding_id") == @id } or raise lacking(path)
        audited_at = open.fetch("audited_at")
        raise time_differs(path, audited_at) unless audited_at == claimed
      end

      #: () -> String
      def claimed = @decision.fetch("first_raised_at")

      #: () -> String
      def commit = @decision.fetch("raised_in")

      #: () -> void
      def whole
        unless @decision["decision"] == "still_holds"
          invalid("only still_holds may give first_raised_at and raised_in",
                  "Drop first_raised_at and raised_in from #{@id}'s decision, or decide it still_holds.")
        end
        return if FIELDS.all? { |field| @decision.key?(field) }

        invalid("first_raised_at and raised_in go together",
                "Give both: first_raised_at, the audited_at of the record that first left #{@id} open, and " \
                "raised_in, the full sha of the commit holding that record; or give neither.")
      end

      # The record's path and the record as the claimed commit held it, refused when it holds none or cannot be read.
      #: (AuditRecords, String) -> [String, AuditRecord]
      def read(records, principle_id)
        records.at(principle_id, commit) or raise not_found(records, principle_id)
      rescue Error => e
        raise unless %w[invalid_audit_record unparseable_audit].include?(e.payload.fetch("code"))

        raise Error.new("raised_in_unreadable", "Prior finding #{@id}: the record at raised_in #{commit} cannot be " \
                                                "read: #{e.payload.fetch("message")}",
                        "Cite another commit whose record holds #{@id}, or drop first_raised_at and raised_in.",
                        fields: e.payload["fields"])
      end

      #: () -> bool
      def earlier?
        Time.iso8601(claimed) < Time.iso8601(@stored.to_s)
      rescue ArgumentError
        false
      end

      #: (AuditRecords, String) -> Error
      def not_found(records, principle_id)
        paths = "#{records.file(principle_id)} or #{records.earlier_file(principle_id)}"
        Error.new("raised_in_not_found", "Prior finding #{@id}: commit #{commit} holds no audit record at #{paths}",
                  "Set raised_in to the full sha of a commit holding #{paths} that left #{@id} open, as " \
                  "git log --follow on the record finds it; outside git, drop first_raised_at and raised_in.")
      end

      #: (String) -> Error
      def lacking(path)
        Error.new("raised_in_lacks_finding",
                  "Prior finding #{@id}: #{path} at #{commit} leaves no finding #{@id} deferred or accepted",
                  "Set raised_in to a commit whose record leaves #{@id} deferred or accepted, or drop " \
                  "first_raised_at and raised_in.")
      end

      #: (String, String) -> Error
      def time_differs(path, audited_at)
        Error.new("raised_in_time_differs",
                  "Prior finding #{@id}: #{path} at #{commit} was audited at #{audited_at}, not #{claimed}",
                  "Set first_raised_at to #{audited_at}, that record's audited_at, or cite the commit of the record " \
                  "audited at #{claimed}.")
      end

      #: () -> Error
      def not_earlier
        Error.new("first_raised_not_earlier",
                  "Prior finding #{@id}: #{claimed} is not earlier than its first_raised_at, #{@stored}",
                  "Drop first_raised_at and raised_in from #{@id}'s decision; the record keeps #{@stored}, and only " \
                  "an earlier record replaces it.")
      end

      #: (String, String) -> bot
      def invalid(why, repair)
        raise Error.new("invalid_decision", "Prior finding #{@id}: #{why}", repair)
      end
    end
  end
end

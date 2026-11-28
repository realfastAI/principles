# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # show-audit --findings: only the findings of an audit record, and of the last completed record an open one
    # keeps, each placed by its status, base_commit and audited_at, for an agent that needs what the last audit found
    # without every member it judged.
    class AuditFindings
      # record is the record as show-audit prints it whole; kept, the last completed record an open one keeps, as
      # printed whole, or nil.
      #: (Hash[String, untyped], Hash[String, untyped]?) -> void
      def initialize(record, kept)
        @record = record
        @kept = kept
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h
        shown = { "principle_id" => @record.fetch("principle_id"), **placing(@record) }
        @kept ? shown.merge("last_completed" => placing(@kept)) : shown
      end

      private

      # record's findings, with its status, the commit it began from, whose text its evidence was read in, and
      # audited_at, which place them.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def placing(record) = record.slice("status", "base_commit", "audited_at", "findings")
    end
  end
end

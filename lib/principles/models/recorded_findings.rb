# typed: strict
# frozen_string_literal: true

require_relative "open_finding"
require_relative "recorded_finding"
require_relative "recorded_members"
require_relative "write_up_repoint"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The findings an audit record's own audit recorded, whatever it did about each, with the principle, audit time
    # and members that audit recorded them under. AuditRecord#left_open decides whose findings are open; these are
    # only its own. Callers reach them through AuditRecord.
    class RecordedFindings
      #: (Array[Hash[String, untyped]], principle_id: String, audited_at: String?, members: RecordedMembers) -> void
      def initialize(entries, principle_id:, audited_at:, members:)
        @findings = entries.map { |finding| RecordedFinding.new(finding) } #: Array[RecordedFinding]
        @principle_id = principle_id
        @audited_at = audited_at
        @members = members
        freeze
      end

      # The findings as the record's file holds them.
      #: () -> Array[Hash[String, untyped]]
      def to_a = @findings.map(&:to_h)

      # Those its audit deferred or accepted, each with the members as it recorded them.
      #: () -> Array[OpenFinding]
      def left_open
        @findings.select(&:open?).map do |finding|
          OpenFinding.new(finding, principle_id: @principle_id, audited_at: @audited_at, members: @members)
        end
      end

      # The ids of those its audit fixed.
      #: () -> Array[String]
      def fixed_ids = @findings.select(&:fixed?).map(&:id)

      # These findings with each one a repoint names moved by it, dated at; the last repoint naming one wins.
      #: (Array[WriteUpRepoint], at: String) -> RecordedFindings
      def repointed(repoints, at:)
        by_finding = repoints.to_h { |repoint| [repoint.finding_id, repoint] }
        moved = @findings.map do |finding|
          repoint = by_finding[finding.id]
          repoint ? repoint.applied_to(finding, at: at) : finding
        end
        RecordedFindings.new(moved.map(&:to_h), principle_id: @principle_id, audited_at: @audited_at,
                                                members: @members)
      end

      # The path of each file they point at: their evidence and write-ups.
      #: () -> Array[String]
      def cited_paths = @findings.flat_map(&:cited_paths).uniq
    end
  end
end

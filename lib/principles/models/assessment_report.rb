# typed: strict
# frozen_string_literal: true

require_relative "assessment_answer"
require_relative "member_grounds"
require_relative "member_moves"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What an assessment reported beyond its findings, which its audit's record and commit carry: by member id, the
    # fields of each member's record entry, such as its assessment and its check's result, and the paths
    # its recent decision cites, which the record does not keep but the completed audit asks to commit when they
    # differ from HEAD. The open record keeps it for the correction to read back, and the correction's basis
    # carries only those paths and the record's digest; this is the one owner of how it is carried.
    class AssessmentReport
      # The report of the answer assessed, each assessment it makes, rather than carries, with the grounds it was
      # judged on.
      #: (AssessmentAnswer, MemberGrounds) -> AssessmentReport
      def self.answered(assessed, grounds)
        fields = assessed.entry_fields.to_h do |id, entry|
          kept = entry["assessment"]
          [id, kept && !kept["carried_forward"] ? entry.merge("assessment" => kept.merge(grounds.of(id))) : entry]
        end
        new(fields, recent_decision_paths: assessed.recent_decision_paths)
      end

      # The report an open record keeps for its correction to read back: each member's entry without the hash and key
      # the record adds, under the ids of any members moves moved, with the recent decision's paths, which the basis
      # carries. A completed record read back so gives the report that completed it, for an identical retry.
      #: (AuditRecord, CorrectionBasis, MemberMoves) -> AssessmentReport
      def self.recorded(record, basis, moves)
        fields = record.to_h.fetch("members").transform_values { |entry| entry.except("sha256", "key") }
        new(moves.hashes(fields), recent_decision_paths: basis.to_h.fetch("recent_decision_paths", []))
      end

      # The paths the recent decision cites as evidence.
      #: Array[String]
      attr_reader :recent_decision_paths

      # entry_fields are, by member id, the fields the assessment reported for that member's record entry.
      #: (?Hash[String, Hash[String, untyped]], ?recent_decision_paths: Array[String]) -> void
      def initialize(entry_fields = {}, recent_decision_paths: [])
        @entry_fields = entry_fields #: Hash[String, Hash[String, untyped]]
        @recent_decision_paths = recent_decision_paths
        freeze
      end

      # The fields the assessment reported for the record entry of the member known by id, or none.
      #: (String) -> Hash[String, untyped]
      def entry_fields_of(id) = @entry_fields.fetch(id, {})

      # What a correction basis carries of it: the recent decision's paths, which no record keeps, when there are any.
      # The open record keeps the rest.
      #: () -> Hash[String, untyped]
      def basis_fields = @recent_decision_paths.empty? ? {} : { "recent_decision_paths" => @recent_decision_paths }

      NONE = new #: AssessmentReport
    end
  end
end

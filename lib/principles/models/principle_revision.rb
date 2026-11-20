# typed: strict
# frozen_string_literal: true

require "digest"
require_relative "../error"
require_relative "project"
require_relative "principle"
require_relative "audit_record"
require_relative "principle_file_revision"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The exact committed map and optional completed audit selected under one identity and revision.
    class PrincipleRevision
      #: (String, String, project: Project) -> PrincipleRevision
      def self.load(id, commit, project:) = new(id, commit, project)

      #: String
      attr_reader :id, :commit
      #: Principle?
      attr_reader :map
      #: AuditRecord?
      attr_reader :audit

      #: (String, String, Project) -> void
      def initialize(id, commit, project)
        @id = id.dup.freeze #: String
        @commit = commit.dup.freeze #: String
        captured = project.history.captured_head
        @map_text = nil #: String?
        @audit_text = nil #: String?
        @map = selected_map(project.principles, captured) #: Principle?
        @audit = selected_audit(project.audit_records, captured) #: AuditRecord?
        freeze
      end

      #: () -> bool
      def absent? = @map.nil? && @audit.nil?

      # Both files were captured completely: null is known absence, never a failed read.
      #: () -> Hash[String, String?]
      def fingerprints
        { "map_sha256" => @map_text && Digest::SHA256.hexdigest(@map_text).freeze,
          "audit_sha256" => @audit_text && Digest::SHA256.hexdigest(@audit_text).freeze }.freeze
      end

      #: (PrincipleRevision) -> bool
      def unchanged_bytes?(other)
        @id == other.id && @map_text == other.map_text && @audit_text == other.audit_text
      end

      # One selected identity/revision must agree in raw fingerprints and every interpreted map/audit fact.
      #: (PrincipleRevision) -> bool
      def same_selection?(other) = selection_facts == other.selection_facts

      #: (PrincipleRevision) -> bool
      def retains_audit?(source)
        @audit&.to_h&.except("principle_id") == source.audit&.to_h&.except("principle_id")
      end

      #: (PrincipleRevision) -> bool
      def retains_metadata?(source)
        @map&.to_h&.except("description", "members", "format", "predecessor") ==
          source.map&.to_h&.except("description", "members", "format", "predecessor")
      end

      protected

      #: String?
      attr_reader :map_text, :audit_text

      # The complete named value used only for equality; nested snapshot facts are already owned and immutable.
      #: () -> Hash[String, untyped]
      def selection_facts
        { "principle_id" => @id, "commit" => @commit, "fingerprints" => fingerprints,
          "map" => @map&.to_h, "audit" => @audit&.to_h }.freeze
      end

      private

      #: (MappedPrinciples, CapturedHead) -> Principle?
      def selected_map(maps, captured)
        @map_text = selected_text([maps.file(@id), maps.earlier_file(@id)], captured)
        @map_text && maps.parsed_history(@id, @map_text, commit: @commit)
      rescue Error => e
        raise e.including("inspected_commit" => @commit, "check_phase" => "capture_map")
      end

      #: (AuditRecords, CapturedHead) -> AuditRecord?
      def selected_audit(records, captured)
        @audit_text = selected_text([records.file(@id), records.earlier_file(@id)], captured)
        @audit_text && records.parsed_history(@id, @audit_text)
      rescue Error => e
        raise e.including("inspected_commit" => @commit, "check_phase" => "capture_audit")
      end

      #: (Array[String], CapturedHead) -> String?
      def selected_text(paths, captured)
        PrincipleFileRevision.load(@id, @commit, paths: paths, captured: captured).text
      end
    end
  end
end

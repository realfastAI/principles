# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "principle"
require_relative "project_history"
require_relative "mapped_principles"
require_relative "principle_predecessor"
require_relative "principle_revision"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Exact committed source/target selections within one predecessor's publication interval.
    class PrinciplePublication
      # A required identity proof failed: retain cause facts and give linked history an applicable repair.
      class ProofError < Error
        REPAIR = "Preserve all surviving map and audit copies. Restore complete ancestry and inspect the " \
                 "exact source anchor and coherent publication; do not retry a partial publication blindly."

        #: (Error) -> ProofError
        def self.from(error)
          return error if error.is_a?(ProofError)

          code = error.payload.fetch("code")
          repair = code == "git_history_unavailable" ? REPAIR : error.payload.fetch("repair")
          wrapped = new(code, error.message, repair)
          wrapped.including(error.payload.except("repair"))
          wrapped.ending_with(error.commands)
          wrapped
        end
      end

      #: (current: Principle, project: Project) -> PrinciplePublication
      def self.load(current:, project:) = from(current, project, nil)

      # This prefix proves only its bounds; its caller selects the endpoint from an enclosing certified interval.
      #: (PrincipleRevision, project: Project) -> PrinciplePublication
      def self.ending_at(revision, project:)
        current = revision.map or
          raise ProofError.new("git_history_unavailable", "#{revision.id} has no map at #{revision.commit}",
                               ProofError::REPAIR)
        from(current, project, revision.commit)
      end

      #: (Principle, Project, String?) -> PrinciplePublication
      def self.from(current, project, through)
        maps = project.principles
        predecessor = PrinciplePredecessor.from(current, principles: maps) or
          raise ProofError.new("git_history_unavailable", "#{current.id} has no supported predecessor",
                               "Use direct-ID history for an unlinked map.", maps.file(current.id))
        new(current.id, predecessor, project, through)
      rescue Error => e
        raise ProofError.from(e)
      end
      private_class_method :from

      #: (String, PrinciplePredecessor, Project, String?) -> void
      def initialize(target, predecessor, project, through)
        @target = target.dup.freeze #: String
        @predecessor = predecessor #: PrinciplePredecessor
        @map_paths = selected_paths(project.principles) #: Array[String]
        @audit_paths = selected_paths(project.audit_records) #: Array[String]
        @states = certify(through, project: project).freeze #: Hash[String, PrincipleRevision]
        freeze
      end
      private_class_method :new

      #: (String) -> Principle
      def map_at(revision) = @states.fetch(revision) { raise unavailable }.map || raise(unavailable)

      #: (String) -> AuditRecord?
      def audit_at(revision) = @states.fetch(revision) { raise unavailable }.audit

      #: () -> PrincipleRevision
      def predecessor_revision = @states.fetch(@predecessor.commit)

      # Immutable exact snapshots already certified by this publication interval.
      #: () -> Hash[String, PrincipleRevision]
      def revisions = @states

      # Every certified commit including both endpoints, newest first; an unchanged map never hides member edits.
      #: () -> Array[[String, Principle]]
      def mapping_states = @states.map { |sha, state| [sha, state.map || raise(unavailable)].freeze }.freeze

      private

      #: (String?, project: Project) -> Hash[String, PrincipleRevision]
      def certify(through, project:)
        source = nil #: PrincipleRevision?
        source = capture_source(project)
        read_interval(source, through, project: project)
      rescue Error => e
        facts = publication_coordinates
        facts["source_hashes"] = source.fingerprints if source
        raise ProofError.from(e).including(facts)
      end

      #: (MappedPrinciples | AuditRecords) -> Array[String]
      def selected_paths(files)
        [@predecessor.principle_id, @target].flat_map { |id| [files.file(id), files.earlier_file(id)] }
                                            .map(&:freeze).freeze
      end

      #: () -> Hash[String, untyped]
      def publication_coordinates
        { "source_id" => @predecessor.principle_id, "source_commit" => @predecessor.commit,
          "target_id" => @target, "map_paths" => @map_paths, "audit_paths" => @audit_paths }
      end

      #: (Project) -> PrincipleRevision
      def capture_source(project)
        source = PrincipleRevision.load(@predecessor.principle_id, @predecessor.commit, project: project)
        unless source.map
          raise unavailable.including("inspected_commit" => source.commit, "check_phase" => "source_anchor",
                                      "source_hashes" => source.fingerprints)
        end

        source
      end

      #: (PrincipleRevision, String?, project: Project) -> Hash[String, PrincipleRevision]
      def read_interval(source, through, project:)
        @published_at = nil #: String?
        captured = project.history.captured_head
        head = through || captured.commit or raise unavailable
        commits = captured.first_parent_range(@predecessor.commit, through: head).commits
        commits.reverse.map { |sha| [sha, selected_at(sha, source, project: project)] }.reverse.to_h
      end

      #: (String, PrincipleRevision, project: Project) -> PrincipleRevision
      def selected_at(sha, original, project:)
        target = PrincipleRevision.load(@target, sha, project: project)
        return checked_target(target) if @published_at

        source = PrincipleRevision.load(@predecessor.principle_id, sha, project: project)
        return source if target.absent? && source.unchanged_bytes?(original)
        unless source.absent? && target.retains_audit?(original) && target.retains_metadata?(original)
          raise inconsistent_pair(source, target)
        end

        map = checked_target(target)
        @published_at = sha
        map
      end

      #: (PrincipleRevision, PrincipleRevision) -> Error
      def inconsistent_pair(source, target)
        unavailable.including("inspected_commit" => target.commit, "check_phase" => "publication_pair",
                              "inspected_source_hashes" => source.fingerprints,
                              "inspected_target_hashes" => target.fingerprints)
      end

      #: (PrincipleRevision) -> PrincipleRevision
      def checked_target(state)
        map = state.map or raise unavailable

        raise unavailable unless map.to_h["format"] == 3 && map.to_h["predecessor"] == @predecessor.to_h

        state
      rescue Error => e
        raise ProofError.from(e).including("inspected_commit" => state.commit, "check_phase" => "destination_link",
                                           "inspected_target_hashes" => state.fingerprints)
      end

      #: () -> ProofError
      def unavailable
        error = ProofError.new(
          "git_history_unavailable", "The linked principle's publication interval cannot be verified",
          ProofError::REPAIR, @map_paths.fetch(2)
        )
        error.including(publication_coordinates)
        error
      end
    end
  end
end

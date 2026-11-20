# typed: strict
# frozen_string_literal: true

require_relative "principle_publication"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Immutable selected snapshots across a principle's exact declared predecessor chain.
    class PrincipleLineage
      #: (current: Principle, project: Project) -> PrincipleLineage
      def self.load(current:, project:)
        new(current, project)
      rescue Error => e
        raise PrinciplePublication::ProofError.from(e)
      end

      #: Hash[String, PrincipleRevision]
      attr_reader :revisions
      #: PrincipleRevision
      attr_reader :oldest_revision

      #: (Principle, Project) -> void
      def initialize(current, project)
        @revisions = {} #: Hash[String, PrincipleRevision]
        publication = PrinciplePublication.load(current: current, project: project)
        @oldest_revision = collect(publication, project) #: PrincipleRevision
        @revisions.freeze
        freeze
      end
      private_class_method :new

      #: (String) -> Principle
      def map_at(commit)
        snapshot = selected(commit)
        snapshot.map || raise(no_map(snapshot))
      end

      #: (String) -> AuditRecord?
      def audit_at(commit) = selected(commit).audit

      private

      #: (PrinciplePublication, Project) -> PrincipleRevision
      def collect(publication, project)
        capture(publication)
        boundary = publication.predecessor_revision
        map = boundary.map or raise no_map(boundary)
        return boundary unless PrinciplePredecessor.from(map, principles: project.principles)

        prefix = PrinciplePublication.ending_at(boundary, project: project)
        predecessor = prefix.predecessor_revision
        # ending_at proves the ordered first-parent prefix; equality would not descend to an earlier anchor.
        raise non_descending(boundary, predecessor) if predecessor.commit == boundary.commit

        collect(prefix, project)
      end

      #: (PrinciplePublication) -> void
      def capture(publication)
        publication.revisions.each do |commit, snapshot|
          previous = @revisions[commit]
          raise conflicting_selection(commit, previous, snapshot) if previous && !previous.same_selection?(snapshot)

          @revisions[commit] ||= snapshot
        end
      end

      #: (String) -> PrincipleRevision
      def selected(commit) = @revisions.fetch(commit) { raise unavailable(commit) }

      #: (String, PrincipleRevision, PrincipleRevision) -> PrinciplePublication::ProofError
      def conflicting_selection(commit, previous, incoming)
        error = PrinciplePublication::ProofError.new(
          "git_history_unavailable", "The route has conflicting selected snapshots at #{commit}",
          PrinciplePublication::ProofError::REPAIR
        )
        error.including("check_phase" => "route_overlap", "selected_commit" => commit,
                        "existing_id" => previous.id, "incoming_id" => incoming.id,
                        "existing_hashes" => previous.fingerprints, "incoming_hashes" => incoming.fingerprints)
        error
      end

      #: (PrincipleRevision, PrincipleRevision) -> PrinciplePublication::ProofError
      def non_descending(boundary, predecessor)
        error = PrinciplePublication::ProofError.new(
          "git_history_unavailable", "Predecessor anchor #{predecessor.commit} does not descend from " \
                                     "selected boundary #{boundary.commit}", PrinciplePublication::ProofError::REPAIR
        )
        error.including("check_phase" => "route_descent", "selected_commit" => boundary.commit,
                        "boundary_id" => boundary.id, "predecessor_id" => predecessor.id,
                        "predecessor_commit" => predecessor.commit)
        error
      end

      #: (PrincipleRevision) -> PrinciplePublication::ProofError
      def no_map(snapshot)
        error = PrinciplePublication::ProofError.new(
          "git_history_unavailable", "#{snapshot.id} has no selected map at #{snapshot.commit}",
          PrinciplePublication::ProofError::REPAIR
        )
        error.including("check_phase" => "route_map", "selected_commit" => snapshot.commit,
                        "selected_id" => snapshot.id, "selected_hashes" => snapshot.fingerprints)
        error
      end

      #: (String) -> PrinciplePublication::ProofError
      def unavailable(commit)
        error = PrinciplePublication::ProofError.new(
          "git_history_unavailable", "#{commit} is outside the certified declared principle route",
          PrinciplePublication::ProofError::REPAIR
        )
        error.including("selected_commit" => commit)
        error
      end
    end
  end
end

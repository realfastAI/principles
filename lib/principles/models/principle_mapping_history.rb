# typed: strict
# frozen_string_literal: true

require_relative "principle_lineage"
require_relative "principle_map_revision"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Immutable map selections for automatic history, bounded by its latest proven incarnation.
    class PrincipleMappingHistory
      #: (current: Principle, project: Project) -> PrincipleMappingHistory
      def self.load(current:, project:) = new(current, project)

      #: (current: Principle, project: Project) -> PrincipleMappingHistory?
      def self.load_if_linked(current:, project:)
        load(current: current, project: project) if PrinciplePredecessor.from(current, principles: project.principles)
      end

      #: Hash[String, PrincipleRevision | PrincipleMapRevision]
      attr_reader :revisions
      #: PrincipleRevision | PrincipleMapRevision
      attr_reader :origin
      #: Array[String]
      attr_reader :map_paths

      #: (Principle, Project) -> void
      def initialize(current, project)
        declared = PrincipleLineage.load(current: current, project: project)
        @revisions = declared.revisions.dup #: Hash[String, PrincipleRevision | PrincipleMapRevision]
        @origin = declared.oldest_revision #: PrincipleRevision | PrincipleMapRevision
        extend_origin(project)
        @map_paths = paths_for_maps(current, project.principles) #: Array[String]
        @revisions.freeze
        freeze
      end
      private_class_method :new

      #: (String) -> Principle
      def map_at(commit)
        selected = @revisions[commit]
        selected&.map || raise(PrinciplePublication::ProofError.new(
          "git_history_unavailable", "#{commit} has no selected map in this automatic history",
          PrinciplePublication::ProofError::REPAIR
        ).including("selected_commit" => commit))
      end

      # The selected child permits this raw fact read, not selection of the returned parent's map.
      #: (String, captured: CapturedHead) -> String?
      def first_parent_of(commit, captured:)
        map_at(commit)
        read_first_parent(commit, captured)
      end

      #: (String, captured: CapturedHead) -> Principle
      def map_at_revision(revision, captured:)
        return map_at(revision) unless revision.end_with?("^")

        child = revision.delete_suffix("^")
        parent = first_parent_of(child, captured: captured)
        selected_parent_map(child, parent)
      end

      private

      #: (Principle, MappedPrinciples) -> Array[String]
      def paths_for_maps(current, maps)
        ids = [current.id, *@revisions.values.map(&:id)].uniq
        ids.flat_map { |id| [maps.file(id), maps.earlier_file(id)] }.map { |path| path.dup.freeze }.freeze
      end

      #: (String, String?) -> Principle
      def selected_parent_map(child, parent)
        raise root_without_parent(child) unless parent

        map_at(parent)
      rescue Error => e
        raise PrinciplePublication::ProofError.from(e).including(
          "child_commit" => child, "parent_commit" => parent, "check_phase" => "parent_map"
        )
      end

      #: (String) -> PrinciplePublication::ProofError
      def root_without_parent(child)
        PrinciplePublication::ProofError.new(
          "git_history_unavailable", "#{child} is an actual root with no first parent",
          "Choose a selected revision with an in-route parent; preserve current map and audit evidence."
        )
      end

      #: (String, CapturedHead) -> String?
      def read_first_parent(commit, captured)
        captured.first_parent_of(commit)
      rescue Error => e
        raise PrinciplePublication::ProofError.from(e).including(
          "child_commit" => commit, "check_phase" => "parent_read"
        )
      end

      #: (Project) -> void
      def extend_origin(project)
        captured = project.history.captured_head
        loop do
          parent = previous_commit(captured) or break
          snapshot = earlier_map(parent, project)
          break unless snapshot.map

          @revisions[snapshot.commit] = snapshot
          @origin = snapshot
        end
      end

      #: (CapturedHead) -> String?
      def previous_commit(captured)
        captured.first_parent_of(@origin.commit)
      rescue Error => e
        raise PrinciplePublication::ProofError.from(e).including(
          "selected_id" => @origin.id, "selected_commit" => @origin.commit, "check_phase" => "origin_parent"
        )
      end

      #: (String, Project) -> PrincipleMapRevision
      def earlier_map(commit, project)
        PrincipleMapRevision.load(@origin.id, commit, project: project)
      rescue Error => e
        raise PrinciplePublication::ProofError.from(e).including(
          "selected_id" => @origin.id, "inspected_commit" => commit, "check_phase" => "origin_map"
        )
      end
    end
  end
end

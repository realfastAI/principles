# typed: strict
# frozen_string_literal: true

require_relative "project"
require_relative "principle_file_revision"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One selected committed map and its identity, independent of any audit record.
    class PrincipleMapRevision
      #: (String, String, project: Project) -> PrincipleMapRevision
      def self.load(id, commit, project:) = new(id, commit, project)

      #: String
      attr_reader :id, :commit
      #: Principle?
      attr_reader :map

      #: (String, String, Project) -> void
      def initialize(id, commit, project)
        @id = id.dup.freeze #: String
        @commit = commit.dup.freeze #: String
        maps = project.principles
        captured = project.history.captured_head
        @physical = PrincipleFileRevision.load(@id, @commit, paths: [maps.file(@id), maps.earlier_file(@id)],
                                                             captured: captured) #: PrincipleFileRevision
        text = @physical.text
        @map = text && maps.parsed_history(@id, text, commit: @commit) #: Principle?
        freeze
      end
      private_class_method :new

      # Nil means both candidate entries were successfully checked and absent.
      #: () -> String?
      def text = @physical.text
    end
  end
end

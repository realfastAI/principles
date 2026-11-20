# typed: strict
# frozen_string_literal: true

require_relative "../data/project_files"
require_relative "entry_file"
require_relative "project_history"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The project's root entry files, which a host loads in every session: CLAUDE.md for Claude Code and AGENTS.md for
    # Codex, by each host's documentation. For each it says whether it exists, and, as each EntryFile says, whether it
    # links the other, and whether git tracks it.
    class EntryFiles
      PATHS = %w[CLAUDE.md AGENTS.md].freeze #: Array[String]

      # Each entry file as the project holds it, or nil for one that does not exist. history says which git does not
      # track: a path whose own file, or a file its links lead to, git does not hold, so a fresh clone would not find
      # its text there.
      #: (Data::ProjectFiles, ProjectHistory) -> EntryFiles
      def self.read(files, history)
        new(PATHS.to_h { |path| [path, EntryFile.read(files, path, tracked: history.tracks?(path))] })
      end

      # held maps each entry file's path to the file, or nil when it does not exist.
      #: (Hash[String, EntryFile?]) -> void
      def initialize(held)
        @held = held.freeze #: Hash[String, EntryFile?]
        freeze
      end

      # Each entry file's facts, in PATHS order.
      #: () -> Array[Hash[String, untyped]]
      def to_a = PATHS.map { |path| facts(path) }

      private

      #: (String) -> Hash[String, untyped]
      def facts(path)
        file = @held[path] or return { "path" => path, "exists" => false }

        file.facts((PATHS - [path]).first.to_s)
      end
    end
  end
end

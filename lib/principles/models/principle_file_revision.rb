# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "captured_head"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One committed principle file's exact bytes, or verified absence across its folder alternatives.
    class PrincipleFileRevision
      #: (String, String, paths: Array[String], captured: CapturedHead) -> PrincipleFileRevision
      def self.load(id, commit, paths:, captured:) = new(id, commit, paths, captured)

      #: String?
      attr_reader :text

      #: (String, String, Array[String], CapturedHead) -> void
      def initialize(id, commit, paths, captured)
        @id = id.dup.freeze #: String
        @commit = commit.dup.freeze #: String
        @paths = paths.map { |path| path.dup.freeze }.freeze #: Array[String]
        @text = selected_text(captured)&.dup&.freeze #: String?
        freeze
      end

      private

      #: (CapturedHead) -> String?
      def selected_text(captured)
        entries = @paths.filter_map { |path| captured.raw_entry_at(@commit, path) }
        raise unavailable if entries.length > 1

        entry = entries.first or return nil
        raise unavailable unless entry.fetch("type") == "blob" && %w[100644 100755].include?(entry.fetch("mode"))

        entry.fetch("bytes")
      end

      #: () -> Error
      def unavailable
        Error.new("git_history_unavailable", "The committed pair of #{@id} cannot be selected at #{@commit}",
                  "Preserve all map and audit copies and inspect their exact committed entries.")
             .including("principle_id" => @id, "commit" => @commit)
      end
    end
  end
end

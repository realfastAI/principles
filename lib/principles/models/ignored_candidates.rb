# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The candidate files git ignores, which this tool names but never reads. A folder git ignores can hold many
    # copies of instruction files written there by specs or builds, and listing each buries a file ignored on
    # its own, such as personal settings. So a file under a folder git ignores is counted under the
    # shallowest such folder, and only the rest are listed.
    class IgnoredCandidates
      # paths are the ignored candidates; folders are every folder above one that git ignores, each ending in "/".
      #: (paths: Array[String], folders: Array[String]) -> void
      def initialize(paths:, folders:)
        @paths = paths #: Array[String]
        @folders = folders #: Array[String]
        freeze
      end

      # The inventory's ignored files and ignored folders.
      #: () -> Hash[String, untyped]
      def listing = { "ignored" => on_their_own, "ignored_folders" => by_folder }

      # Each ignored candidate with no folder above it that git ignores.
      #: () -> Array[String]
      def on_their_own
        @paths.reject { |path| shallowest_folder(path) }.sort
      end

      # Each shallowest folder git ignores, and how many ignored candidates it holds.
      #: () -> Array[Hash[String, untyped]]
      def by_folder
        @paths.filter_map { |path| shallowest_folder(path) }.tally.sort.map do |folder, count|
          { "folder" => folder, "candidates" => count }
        end
      end

      private

      #: (String) -> String?
      def shallowest_folder(path)
        @folders.select { |folder| path.start_with?(folder) }.min_by(&:length)
      end
    end
  end
end

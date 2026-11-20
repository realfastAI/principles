# typed: strict
# frozen_string_literal: true

require "open3"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # What git ignores among a project's candidate files: the files, by every ignore file git reads, a global one
    # included, so build output and personal settings are named rather than read, and each folder above
    # them that git ignores, so a build folder's many copies can be counted once.
    class IgnoredByGit
      #: (String, Array[String]) -> void
      def initialize(root, candidates)
        @root = root
        @candidates = candidates
        freeze
      end

      # The ignored candidates and the ignored folders above them, or nil when git gave no answer to either
      # question: outside a repository, and when git refuses one, as one of doubtful ownership. nil means not
      # checked, not that nothing is ignored, so it must not become empty lists; and both or neither, since a
      # folder list git did not give would make every file look ignored on its own.
      #: () -> Hash[String, Array[String]]?
      def facts
        paths = asked(@candidates) or return nil
        folders = paths.empty? ? [] : asked(ancestor_folders(paths))
        { "ignored" => paths.sort, "ignored_ancestor_folders" => folders.sort } if folders
      end

      private

      # Every folder above each path, as "a/" and "a/b/", once each: the trailing "/" lets git match a folder
      # pattern such as build/.
      #: (Array[String]) -> Array[String]
      def ancestor_folders(paths)
        paths.flat_map do |path|
          folders = path.split("/").first(path.count("/"))
          (1..folders.length).map { |depth| "#{folders.first(depth).join("/")}/" }
        end.uniq
      end

      # The paths git ignores, or nil when it gave no answer.
      #: (Array[String]) -> Array[String]?
      def asked(paths)
        output, _, status = Open3.capture3("git", "-C", @root, "check-ignore", "-z", "--stdin",
                                           stdin_data: paths.map { |path| "#{path}\0" }.join)
        output.split("\0") if status.exitstatus.to_i <= 1
      rescue SystemCallError
        nil
      end
    end
  end
end

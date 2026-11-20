# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The files, and the files their links lead to, that differ from HEAD or are not yet committed, as ProjectHistory
    # found them for a write-up or an audit's members, and the refusal each gives while there are any.
    class UncommittedFiles
      # An existing assessment keeps its prepared answer while these whole files are brought back to a commit.
      ASSESSMENT_REPAIR = "An audit requires the whole map and member files to be committed, even when an edit " \
                          "is outside a judged passage.\nCommit the intended changes in the named files, then retry " \
                          "the same answer unchanged. If that retry is refused as stale, follow its repair to " \
                          "start a new audit."

      #: (Array[String]) -> void
      def initialize(paths)
        @paths = paths
        freeze
      end

      # Refuses the write-up at path while it, or a file its links lead to, differs from HEAD: the record is committed
      # pointing at it, so a fresh clone would find nothing there.
      #: (String) -> void
      def refuse_write_up(path)
        return if @paths.empty?

        linked = @paths - [path]
        raise Error.new("uncommitted_files",
                        "The write-up at #{path} differs from the last commit" +
                        (linked.empty? ? "" : ", through #{linked.join(", ")}"),
                        "The record will point at the write-up as committed.\n" \
                        "Commit the write-up, then submit the same answer again.")
      end

      # Refuses an audit of id while any of its map or members differs from HEAD.
      #: (String) -> void
      def refuse_audit(id)
        return if @paths.empty?

        raise Error.new("uncommitted_files", "The map or members of #{id} differ from the last commit: " \
                                             "#{@paths.join(", ")}",
                        "An audit assesses the map and members as committed, so its record can name the commit " \
                        "it began from.\nCommit them, then start it again: #{Error::EXECUTABLE} start-audit #{id}")
      end
    end
  end
end

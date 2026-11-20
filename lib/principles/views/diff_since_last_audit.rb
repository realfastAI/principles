# typed: strict
# frozen_string_literal: true

require_relative "shell_word"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The command that shows the edits to a member's file since the last full audit's base commit, to the files as
    # they are now, which the audit judges. Each word is quoted for the shell, and each path read by git as written,
    # not as a pattern. Renames are followed, so over a moved file's path then and now the diff shows the
    # edit, not a new file.
    class DiffSinceLastAudit
      # last_audited_commit is the last full audit's base commit; paths are the member's file then and now, once each;
      # to is the commit the diff ends at, or nil for the files as they are now.
      #: (last_audited_commit: String, paths: Array[String], ?to: String?) -> void
      def initialize(last_audited_commit:, paths:, to: nil)
        @last_audited_commit = last_audited_commit
        @paths = paths
        @to = to
        freeze
      end

      #: () -> String
      def to_s
        words = [@last_audited_commit, *@to, "--", *@paths].map { |word| ShellWord.new(word).to_s }
        "git --literal-pathspecs diff -M #{words.join(" ")}"
      end
    end
  end
end

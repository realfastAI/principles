# typed: strict
# frozen_string_literal: true

require_relative "shell_word"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The command that shows each commit's edits to a member's own lines since the last full audit's base commit, as
    # git traces those lines back from the commit now, so a short member of a long file is read without the rest of
    # the file's edits. Each commit is named by its short id and subject, and each word is quoted for the shell.
    class LineHistorySinceLastAudit
      # last_audited_commit is the last full audit's base commit; path is the member's file, at the same path then
      # and now; first_line and last_line are the lines it spans now, 1-based; to is the commit the history ends at,
      # or nil for HEAD, where git reads those lines, so it must hold the file as it is now, as HEAD does once an audit
      # has refused a member file that differs from it.
      #: (last_audited_commit: String, path: String, first_line: Integer, last_line: Integer, ?to: String?) -> void
      def initialize(last_audited_commit:, path:, first_line:, last_line:, to: nil)
        @last_audited_commit = last_audited_commit
        @path = path
        @first_line = first_line
        @last_line = last_line
        @to = to
        freeze
      end

      #: () -> String
      def to_s
        range = "#{@last_audited_commit}..#{@to || "HEAD"}"
        words = ["--format=%h %s", "-L", "#{@first_line},#{@last_line}:#{@path}", range]
        "git log #{words.map { |word| ShellWord.new(word).to_s }.join(" ")}"
      end
    end
  end
end

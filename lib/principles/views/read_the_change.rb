# typed: strict
# frozen_string_literal: true

require_relative "diff_since_last_audit"
require_relative "line_history_since_last_audit"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The command a member's read_the_change prints: the history of its own lines when it is handed them, else the
    # diff of its file over its paths.
    class ReadTheChange
      # since is the commit the change is read from; paths are the member's file then and now, once each; lines are
      # its first_line and last_line now, given only when Member#traced_by_lines? says its change reads by them; to
      # is the commit the change ends at, which holds the file as it is now, or nil for HEAD and the files now.
      #: (since: String, paths: Array[String], lines: Hash[String, Integer]?, ?to: String?) -> void
      def initialize(since:, paths:, lines:, to: nil)
        @since = since
        @paths = paths
        @lines = lines
        @to = to
        freeze
      end

      #: () -> String
      def to_s
        lines = @lines
        return DiffSinceLastAudit.new(last_audited_commit: @since, paths: @paths, to: @to).to_s unless lines

        LineHistorySinceLastAudit.new(last_audited_commit: @since, path: @paths.fetch(0),
                                      first_line: lines.fetch("first_line"), last_line: lines.fetch("last_line"),
                                      to: @to).to_s
      end
    end
  end
end

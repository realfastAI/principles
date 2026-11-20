# typed: strict
# frozen_string_literal: true

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # git run in one directory, with its own messages kept off this tool's output: its output and whether it
    # succeeded, and an empty failure where git cannot be started.
    class GitCommand
      # git reads each path this tool passes as itself, never as a glob or a :(magic) pathspec, so a member's
      # file name cannot take in other files.
      LITERAL = { "GIT_LITERAL_PATHSPECS" => "1" }.freeze #: Hash[String, String]

      #: (String) -> void
      def initialize(directory)
        @directory = directory
        freeze
      end

      # Legacy readers retain their success/failure pair; permission checks can inspect the exact status.
      #: (Array[String]) -> [String, bool]
      def run(arguments)
        output, status = run_with_status(arguments)
        [output, status&.zero? || false]
      end

      # nil means no numeric exit code, as a launch failure or termination by signal.
      #: (Array[String]) -> [String, Integer?]
      def run_with_status(arguments)
        output = IO.popen(LITERAL, ["git", "-C", @directory, *arguments], err: File::NULL, &:read)
        [output, Process.last_status&.exitstatus]
      rescue SystemCallError
        ["", nil]
      end
    end
  end
end

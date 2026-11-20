# typed: strict
# frozen_string_literal: true

require_relative "prompts"
require_relative "../prose_list"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How a completed audit in git says to commit what it changed: the command committing those files alone, with
    # its default subject, which AuditChanges#commit builds. ByHand is the form outside git, with no command.
    class AuditCommit
      #: (files_to_commit: Array[String], subject: String, command: String) -> void
      def initialize(files_to_commit:, subject:, command:)
        @files_to_commit = files_to_commit
        @subject = subject
        @command = command
        freeze
      end

      # The command, and beside it what replacing its default subject asks, since an agent reading commit_with
      # alone would otherwise run the default.
      #: () -> Hash[String, String]
      def fields
        { "commit_with" => @command,
          "commit_message_to_replace" => Prompts.text("report-the-completed-audit/replace-the-default-commit-message",
                                                      subject: @subject) }
      end

      # The step that commits the files with commit_with's command, which it names rather than prints a second time,
      # up to the report that follows; its wording is its prompt's. Why the command stops during a
      # merge is its own to say, on stderr.
      #: () -> String
      def next_step
        commit = Prompts.text("report-the-completed-audit/commit-only-what-the-audit-changed",
                              files: ProseList.new(@files_to_commit).to_s)
        "#{commit}\nThen"
      end

      # Outside git, where no command could run as printed: only the files to commit.
      class ByHand
        #: (Array[String]) -> void
        def initialize(files_to_commit)
          @files_to_commit = files_to_commit
          freeze
        end

        #: () -> Hash[String, String]
        def fields = {}

        #: () -> String
        def next_step = "Commit #{ProseList.new(@files_to_commit)}. Then"
      end
    end
  end
end

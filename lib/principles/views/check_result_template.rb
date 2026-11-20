# typed: strict
# frozen_string_literal: true

require_relative "check_notes"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The check_result a checked member's assessment template starts with: its command, a short exit_status
    # placeholder where the run's status goes, and not_run_reason, the alternative, as a placeholder an answer leaves
    # as printed when it reports a run, with its instruction, what to do before replacing it. A check
    # no audit has run, or one changed since, is reviewed before it runs, so it also gives review_basis to fill,
    # and any hidden character it holds is named where that decision is made.
    class CheckResultTemplate
      # The template for the checked member a request lists as entry, with its check, how that stands to the last
      # audit's and any hidden characters in it; nil for a member without a check.
      #: (Hash[String, untyped], reviewed_placeholders: Hash[String, String],
      #|  unchanged_placeholders: Hash[String, String]) -> CheckResultTemplate?
      def self.for(entry, reviewed_placeholders:, unchanged_placeholders:)
        check = entry["check"] or return
        new(check, entry["check_since_last_audit"], entry.fetch("check_hidden_characters", []),
            reviewed_placeholders:, unchanged_placeholders:)
      end

      # reviewed_placeholders gives the text of exit_status, and of not_run_reason and review_basis, which an answer
      # leaves as printed to give neither, for a check reviewed before it runs; unchanged_placeholders gives it for one
      # the last audit ran, whose review_basis left as printed keeps the line that audit kept.
      #: (String, Hash[String, untyped]?, ?Array[String], reviewed_placeholders: Hash[String, String],
      #|  unchanged_placeholders: Hash[String, String]) -> void
      def initialize(check, since_last_audit, hidden_characters = [], reviewed_placeholders:, unchanged_placeholders:)
        @check = check
        @since_last_audit = since_last_audit
        @notes = CheckNotes.new(since_last_audit, hidden_characters) #: CheckNotes
        @unchanged = since_last_audit&.fetch("status") == "unchanged" #: bool
        @placeholders = @unchanged ? unchanged_placeholders : reviewed_placeholders #: Hash[String, String]
        freeze
      end

      # The check_result to fill. An unchanged check's gives its optional fields as values to edit, not instructions:
      # no not_run_reason, and the line its last review rested on.
      #: () -> Hash[String, untyped]
      def to_h
        { "command" => @check, "exit_status" => @placeholders.fetch("exit_status"),
          **(@unchanged ? { "not_run_reason" => nil, "review_basis" => @notes.kept_basis } : placeholders) }
      end

      # How the check stands to the last audit's: unchanged, changed or new, which sets the text it shares with every
      # other check standing so.
      #: () -> String
      def status = @since_last_audit&.fetch("status", nil) || "new"

      # What to do before replacing exit_status that every check of its status shares, ending with that a named check
      # runs at every full audit, which a request prints once for the members it is for.
      #: () -> String
      def shared_instruction
        steps = case status
                when "unchanged" then [Prompts.text("assess-every-member/run-the-check-then-report-it")]
                when "changed"
                  [Prompts.text("assess-every-member/have-a-changed-check-reviewed-before-running-it"), run_reviewed]
                else [Prompts.text("assess-every-member/have-a-new-check-reviewed-before-running-it"), run_reviewed]
                end
        [*steps, Prompts.text("assess-every-member/run-a-named-check-at-every-full-audit")].join(" ")
      end

      # This member's own lines beside the shared instruction: what the check hides, the commit that set or changed
      # it, and the line its last review rested on; nil when it has none.
      #: () -> String?
      def own_instruction
        lines = [@notes.hidden_characters, commit_line, *(@notes.printed_review if status == "unchanged")].compact
        lines.join(" ") unless lines.empty?
      end

      private

      # The optional fields' placeholders, for a check reviewed before it runs.
      #: () -> Hash[String, String]
      def placeholders = @placeholders.slice("not_run_reason", "review_basis")

      # The commit that made a new or changed check what it is now, stated where the run is asked, since the template
      # printed alone has no context beside it; nil outside git, when no commit holds it, or for an unchanged
      # check.
      #: () -> String?
      def commit_line
        commit = @since_last_audit&.fetch("changed_in", nil) or return
        return if status == "unchanged"

        Prompts.text("assess-every-member/name-the-commit-that-made-the-check",
                     commit:, verb: status == "changed" ? "changed" : "set")
      end

      # Run a reviewed check, then report it with what its review rested on.
      #: () -> String
      def run_reviewed
        Prompts.text("assess-every-member/run-the-reviewed-check-and-say-what-its-review-rested-on")
      end
    end
  end
end

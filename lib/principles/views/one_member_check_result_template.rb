# typed: strict
# frozen_string_literal: true

require_relative "check_notes"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The check_result a one-member audit's template starts with for a checked member, whose check is the one the last
    # audit ran, since any other is refused at its start, and the instruction its request gives beside it. It
    # asks for a passing run alone, since one that fails or cannot run is refused as a full audit's to judge, so it
    # prints no not_run_reason and says nothing of how often full audits run it. Its exit_status holds a short
    # placeholder where the integer goes, and what to do, with what the check hides and the line its last review rested
    # on, is the instruction's.
    class OneMemberCheckResultTemplate
      # The template for the checked member a request lists as entry, with how its check stands to the last audit's
      # and any hidden characters in it; nil for a member without a check. exit_status is the placeholder it prints
      # there, its one field: the answer reads the command as the request printed it and keeps the line the last
      # review rested on, so neither is printed to fill. own_listing says the check is this tool's own
      # list-member-problems, which exits 3 while it lists the member.
      #: (Hash[String, untyped], exit_status: String, ?own_listing: bool) -> OneMemberCheckResultTemplate?
      def self.for(entry, exit_status:, own_listing: false)
        return unless entry["check"]

        new(CheckNotes.new(entry["check_since_last_audit"], entry.fetch("check_hidden_characters", [])), exit_status:,
                                                                                                         own_listing:)
      end

      #: (CheckNotes, exit_status: String, ?own_listing: bool) -> void
      def initialize(notes, exit_status:, own_listing: false)
        @notes = notes
        @exit_status = exit_status
        @own_listing = own_listing
        freeze
      end

      # The check_result to fill, with an empty listed_members slot for this tool's own list-member-problems, whose
      # instruction says what goes there.
      #: () -> Hash[String, untyped]
      def to_h = { "exit_status" => @exit_status, **(@own_listing ? { "listed_members" => [] } : {}) }

      # What to do before filling exit_status, which the request gives as context.check_instruction.
      #: () -> String
      def instruction
        [@notes.hidden_characters, Prompts.text("acknowledge-a-change/run-the-check-and-report-it-passing"),
         *@notes.kept_review, own_listing].compact.join(" ")
      end

      private

      # What to report for this tool's own list-member-problems, which exits 3 while it lists the member.
      #: () -> String?
      def own_listing
        Prompts.text("acknowledge-a-change/report-the-exit-status-its-own-listing-gives") if @own_listing
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "missing_files"
require_relative "open_finding"
require_relative "project"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Some open findings, each with its write-up opening where its recorded_at points, as the project's file stands
    # now.
    class FindingWriteUps
      # What to do about a recorded_at that no longer resolves, worded for a write-up rather than a member.
      REPAIR = "Fix the write-up, or point recorded_at at it again with start-audit --open-findings, without a full " \
               "audit."
      # What the repair adds when git detects a rename for the write-up's missing file.
      RENAMED = " git_detected_rename is git's match for its file, to #{MissingFiles::RENAME_MATCH}".freeze #: String

      # The findings records keep open for the next audit, in project.
      #: (Project, Array[AuditRecord]) -> FindingWriteUps
      def self.of(project, records) = new(project, records.flat_map(&:left_open))

      #: (Project, Array[OpenFinding]) -> void
      def initialize(project, findings)
        @project = project
        @findings = findings
        freeze
      end

      # Each finding with its write_up_opening, as list-open-findings prints them.
      #: () -> Array[Hash[String, untyped]]
      def listed
        @findings.map { |finding| finding.listed.merge(opening_fields(finding.recorded_at)) }
      end

      # The findings that are written up somewhere, each with the write-up opening list-open-findings will print for
      # it, so a pointer that lands on a generic line is seen before the answer is submitted.
      #: () -> Array[Hash[String, untyped]]
      def written_up
        fields = %w[finding_id write_up_opening write_up_opening_reason write_up_opening_error]
        listed.select { |finding| finding["recorded_at"] }.map { |finding| finding.slice(*fields) }
      end

      # The id of each deferred finding written up nowhere, its recorded_at null, which the question allows when there
      # is nowhere to point but an agent may take for a pointer left out.
      #: () -> Array[String]
      def deferred_written_up_nowhere
        @findings.select { |finding| finding.action == "deferred" && !finding.recorded_at }.map(&:id)
      end

      # The findings whose write-up can no longer be found where recorded_at points, each by its principle and
      # finding_id, which list-open-findings --short names so a session-start hook shows the broken pointer.
      # It asks git for no rename, which only the full list prints.
      #: () -> Array[Hash[String, untyped]]
      def not_found
        @findings.select { |finding| unresolved?(finding.recorded_at) }
                 .map { |finding| { "principle" => finding.principle_id, "finding_id" => finding.id } }
      end

      private

      # pointer's write_up_opening, or null with the reason: not_recorded, empty_region, or unavailable with the
      # refusal, so one pointer that no longer resolves never refuses the whole list.
      # A url's is null as outside_project, since this tool reads nothing outside the project.
      #: (WriteUpPointer?) -> Hash[String, untyped]
      def opening_fields(pointer)
        return none("not_recorded") unless pointer
        return none("outside_project") if pointer.url

        opening_found(pointer)
      end

      # The write_up_opening pointer leads to, or null with why: empty_region, or unavailable with the refusal.
      #: (WriteUpPointer) -> Hash[String, untyped]
      def opening_found(pointer)
        opening = pointer.opening_in(@project)
        opening ? { "write_up_opening" => opening } : none("empty_region")
      rescue Error => e
        none("unavailable").merge("write_up_opening_error" => unavailable(e.payload, pointer))
      end

      # Whether a recorded pointer no longer resolves in the project's file now; a url names no file here to lose.
      #: (WriteUpPointer?) -> bool
      def unresolved?(pointer)
        return false if pointer.nil? || pointer.url

        pointer.opening_in(@project)
        false
      rescue Error
        true
      end

      # The refusal that left a write-up unavailable, with any rename git detects for its file when that file is
      # missing. The agent checks the match before pointing recorded_at there: this tool does not decide the match
      # is the write-up, as for a member's missing file.
      #: (Hash[String, untyped], WriteUpPointer) -> Hash[String, untyped]
      def unavailable(payload, pointer)
        refused = payload.slice("code", "message")
        rename = @project.history.rename_of(pointer.path) if refused["code"] == "unreadable_file"
        return refused.merge("repair" => REPAIR) unless rename

        refused.merge("git_detected_rename" => rename.merge(starting_at_found(pointer.in_file(rename.fetch("to")))),
                      "repair" => REPAIR + RENAMED)
      end

      # Whether moved, the pointer with its starting_at in the file git matched, still resolves there: its
      # starting_at occurs exactly once there, within its heading's section when it names one, as a member's passage
      # must. A deterministic check of git's match, which the agent then reads as one fact; nothing for a pointer
      # with no starting_at.
      #: (WriteUpPointer) -> Hash[String, bool]
      def starting_at_found(moved)
        moved.starting_at? ? { "starting_at_found_in_rename" => !unresolved?(moved) } : {}
      end

      #: (String) -> Hash[String, untyped]
      def none(reason)
        { "write_up_opening" => nil, "write_up_opening_reason" => reason }
      end
    end
  end
end

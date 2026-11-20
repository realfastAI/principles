# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "members_with_no_baseline"
require_relative "maps_needing_members_or_audit"
require_relative "principles_with_no_completed_audit"
require_relative "record_waiting_on_an_upgrade"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # list-member-problems' result when no member is broken: each changed member, every state's count, and what
    # to do next, with commands for the invocation running now.
    class ProblemResult
      NOTHING_CHANGED = "Nothing to do: every member's own text is as its last audit or acknowledgement recorded it."

      OLDER_STATE = "An older version of this tool kept audit runs in this file. This version does not read " \
                    "it, so an audit recorded only there is not a baseline. Start a new audit to make one."

      # The lead before the acknowledgements, which leaves the agent to judge each change.
      ACKNOWLEDGE_LEAD = "Acknowledge members that still say the same thing with start-audit --member below; if " \
                         "one's meaning changed, or its check is new, changed or fails, run start-audit ID:"

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # report holds "members", the changed members, and "counts"; not_read names older files left unread;
      # no_baseline_files names, by principle, the files to commit so its members with no baseline gain one.
      # acknowledgeable names, by the principles that acknowledge them together, the changed members a one-member
      # audit may judge.
      # waiting names each principle whose record a later copy wrote, whose members are not checked.
      #: (Hash[String, untyped], ?not_read: Array[String], ?no_baseline_files: Hash[String, Array[String]],
      #|  ?acknowledgeable: Hash[Array[String], Array[String]], ?waiting: Array[RecordWaitingOnAnUpgrade])
      #|  -> Hash[String, untyped]
      def checked(report, not_read: [], no_baseline_files: {}, acknowledgeable: {}, waiting: [])
        checked_naming_commands(report, not_read:, no_baseline_files:, acknowledgeable:, waiting:).first
      end

      # The same result, and whether its next_action names a command, before which --short names the project once,
      # so no view reads the action's text to find one.
      #: (Hash[String, untyped], ?not_read: Array[String], ?no_baseline_files: Hash[String, Array[String]],
      #|  ?acknowledgeable: Hash[Array[String], Array[String]], ?waiting: Array[RecordWaitingOnAnUpgrade])
      #|  -> [Hash[String, untyped], bool]
      def checked_naming_commands(report, not_read: [], no_baseline_files: {}, acknowledgeable: {}, waiting: [])
        unless not_read.empty?
          report = report.merge("not_read" => not_read.map { |file| { "file" => file, "because" => OLDER_STATE } })
        end
        report = report.merge("records_waiting_on_an_upgrade" => waiting.map(&:to_h)) unless waiting.empty?
        action, commands = next_action(report, no_baseline_files:, acknowledgeable:, waiting:)
        [report.merge("next_action" => action), commands]
      end

      # For each principle with members no baseline holds, what gives them one: outside git a completed audit,
      # and in git committing the files no_baseline_files names.
      #: (Hash[String, untyped], Hash[String, Array[String]]) -> Array[MembersWithNoBaseline]
      def no_baseline_actions(report, no_baseline_files)
        report.fetch("no_baseline_because", {}).map do |id, because|
          MembersWithNoBaseline.new(id: id, count: report.fetch("compared_with").fetch(id).fetch("no_baseline"),
                                    because: because, audit: @invocation.in_project("start-audit", id),
                                    files: no_baseline_files.fetch(id, []))
        end
      end

      private

      # What to do next for report, each kind of action on lines of its own, or NOTHING_CHANGED when none applies,
      # and whether it names a command: every changed, unaudited and mapping action does, a no-baseline one as it
      # says, and neither the mapping notice nor a waiting principle's update sentence does.
      #: (Hash[String, untyped], no_baseline_files: Hash[String, Array[String]],
      #|  acknowledgeable: Hash[Array[String], Array[String]], waiting: Array[RecordWaitingOnAnUpgrade])
      #|  -> [String, bool]
      def next_action(report, no_baseline_files:, acknowledgeable:, waiting:)
        waits = waiting.map(&:principle)
        mapping = MapsNeedingMembersOrAudit.new(@invocation, report: report, files_to_commit: no_baseline_files,
                                                             waiting: waits)
        commanding = [changed_action(report, acknowledgeable, waits), unaudited_action(report, waits)].compact
        no_baseline = no_baseline_actions(report, no_baseline_files)
        action = [*commanding, mapping.notice, *no_baseline.map(&:to_s), *mapping.actions,
                  *waiting.map(&:to_s)].compact.join("\n")
        [action.empty? ? NOTHING_CHANGED : action, names_a_command?(commanding, no_baseline, mapping)]
      end

      # Whether any of the actions that may name a command does.
      #: (Array[String], Array[MembersWithNoBaseline], MapsNeedingMembersOrAudit) -> bool
      def names_a_command?(commanding, no_baseline, mapping)
        !commanding.empty? || no_baseline.any?(&:names_a_command?) || !mapping.actions.empty?
      end

      # For each principle with a changed member, its audits, each command ending its own line: where acknowledgeable
      # names members a one-member audit may judge, one acknowledgement for all of them, filled and shell-quoted so
      # the agent types no id, after one lead saying when to audit in full instead; the full audit for a principle
      # with a changed member no acknowledgement may judge, with no condition, as nothing else applies to it. None for
      # a principle in waits, whose audits wait on an upgrade.
      #: (Hash[String, untyped], Hash[Array[String], Array[String]], Array[String]) -> String?
      def changed_action(report, acknowledgeable, waits)
        changed = report.fetch("members").group_by { it.fetch("principle") }.except(*waits)
        acknowledging = acknowledgeable.map { |ids, members| acknowledge_line(ids, members) }
        full = changed.filter_map { |id, members| full_audit_line(id, members, acknowledged_in(acknowledgeable, id)) }
        lines = [*(ACKNOWLEDGE_LEAD unless acknowledging.empty?), *acknowledging, *full]
        lines.empty? ? nil : lines.join("\n")
      end

      # The acknowledgement of every member in members by the principles ids names, each of those it maps.
      #: (Array[String], Array[String]) -> String
      def acknowledge_line(ids, members)
        @invocation.listed_in_project("start-audit", ids, options: members.flat_map { ["--member", it] })
      end

      # The members an acknowledgement in acknowledgeable takes in for principle id.
      #: (Hash[Array[String], Array[String]], String) -> Array[String]
      def acknowledged_in(acknowledgeable, id) = acknowledgeable.select { |ids, _| ids.include?(id) }.values.flatten

      # The full audit of principle id, for its changed members no acknowledgement may judge, or nil when the
      # acknowledgement takes in every one.
      #: (String, Array[Hash[String, untyped]], Array[String]) -> String?
      def full_audit_line(id, members, acknowledgeable)
        return if members.all? { acknowledgeable.include?(it.fetch("id")) }

        other = acknowledgeable.empty? ? "" : " other"
        "Audit #{id} in full to judge its#{other} changed members: #{@invocation.in_project("start-audit", id)}"
      end

      # Members compared only with the commit that mapped them have never been assessed, so neither "changed" nor
      # "unchanged" says whether they carry their principle: those added to an audited principle by principle, and
      # every principle awaiting its first full audit in one line, but those in waits.
      #: (Hash[String, untyped], Array[String]) -> String?
      def unaudited_action(report, waits)
        awaiting = report.fetch("awaiting_first_audit", [])
        lines = [added_members_action(report, awaiting + waits)]
        unless awaiting.empty?
          audits = awaiting.map { |id| @invocation.in_project("start-audit", id) }
          lines << PrinciplesWithNoCompletedAudit.new(ids: awaiting, audits:).to_s
        end
        lines.compact.empty? ? nil : lines.compact.join("\n")
      end

      # Each principle's members no audit has assessed, on its own line with its audit, but for the principles
      # left_out names: those awaiting their first full audit, and those whose audits wait on an upgrade.
      #: (Hash[String, untyped], Array[String]) -> String?
      def added_members_action(report, left_out)
        unseen = report.fetch("compared_with", {}).except(*left_out).filter_map do |id, counts|
          count = counts.fetch("mapping_commit", 0)
          next unless count.positive?

          "#{count} member#{"s" unless count == 1} of #{id}: #{@invocation.in_project("start-audit", id)}"
        end
        return nil if unseen.empty?

        ["No audit has assessed these yet, so whether they carry their principle is unknown, changed or not:",
         *unseen].join("\n")
      end
    end
  end
end

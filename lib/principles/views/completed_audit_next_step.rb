# typed: strict
# frozen_string_literal: true

require_relative "audit_changes"
require_relative "audit_commit"
require_relative "invocation"
require_relative "principle_with_changed_members"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A completed audit's next step, from what it changed and how to commit it: commit and report, re-audit each other
    # principle its fixes changed, and, when its members changed during the audit, audit this principle again.
    class CompletedAuditNextStep
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The next step after principle id's audit completed with changes, committed as commit says.
      #: (String, AuditChanges, AuditCommit | AuditCommit::ByHand) -> String
      def to_s(id, changes, commit)
        ["#{commit.next_step} report the outcome to the project's owner.\n",
         others_changed(changes.other_changed), again(id, changes.members_changed)].join.chomp
      end

      private

      # The line asking for principle id's audit again when its members changed during the audit; nothing when none
      # did, since nothing then needs a second audit.
      #: (String, MembersChangedDuringAudit) -> String
      def again(id, members_changed)
        return "" unless members_changed.any?

        "After members change, audit this principle again: #{@invocation.in_project("start-audit", id)}"
      end

      # The other principles whose members this audit's fixes changed, each to re-audit, or one member's edit
      # to acknowledge; the agent judges which. Nothing when there are none.
      #: (Array[PrincipleWithChangedMembers]) -> String
      def others_changed(others)
        return "" if others.empty?

        commands = others.map { |each| "#{@invocation.in_project("start-audit", each.principle_id)}\n" }
        "This audit's fixes also changed or broke members of other principles, listed under " \
          "other_principles_with_changed_members. Repair a broken one from show-principle's repair_with. To " \
          "acknowledge one member's edit instead, add --member MEMBER to its audit. Re-audit each:\n#{commands.join}"
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "json"
require_relative "invocation"
require_relative "member_row"
require_relative "problem_lines"
require_relative "prompts"
require_relative "record_waiting_on_an_upgrade"
require_relative "visible_text"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # list-member-problems --commits-after COMMIT --hook-event EVENT: the whole JSON the plugin's after-commit hook
    # prints for Claude Code, which puts its additionalContext beside the Bash call's result, or nothing at all.
    # Claude Code asks for that text to state facts, not to give orders, so it says what the commits changed,
    # which command shows more and, under the plugin, which skill to start from. It names that skill as a user
    # invokes it in Claude Code, /principles, the only host the plugin installs it for.
    class MembersACommitChanged
      NOTHING = Lines.new(stdout: "", stderr: "", status: 0).freeze #: Lines

      # skill says whether this session has the principles skill, which only the plugin installs; without it the
      # command the report names is where to start.
      #: (Invocation, skill: bool) -> void
      def initialize(invocation, skill:)
        @invocation = invocation
        @skill = skill
        freeze
      end

      # changed is each member the commits changed, as list-member-problems lists it; others is how many other changed
      # members it still lists. Those it marks waiting_on_an_upgrade are named apart, with the waits that say why, and
      # no audit to run; the others still listed are counted beside them too, since this copy may
      # audit those.
      #: (String, Array[Hash[String, untyped]], others: Integer, ?waits: Array[RecordWaitingOnAnUpgrade]) -> Lines
      def changed(event, changed, others:, waits: [])
        waiting, auditable = changed.partition { |member| member["waiting_on_an_upgrade"] }
        reported(event, [*(to_audit(auditable, others) unless auditable.empty?),
                         *(waiting_lines(waiting, waits) unless waiting.empty?),
                         *(listed_beside_the_waiting(others) if auditable.empty?)])
      end

      # A refusal with code, which the commits could have caused.
      #: (String, String) -> Lines
      def refused(event, code)
        reported(event, [Prompts.text("report-after-a-commit/it-refused-after-the-commits-touched-the-maps",
                                      code: VisibleText.new(code).to_s), command])
      end

      private

      # The members to audit, as rows, then what shows more and, in a session that has it, the skill to start from.
      #: (Array[Hash[String, untyped]], Integer) -> Array[String]
      def to_audit(changed, others)
        [Prompts.text("report-after-a-commit/the-commits-changed-these-members"), *rows(changed),
         *still_listed(others), Prompts.text("report-after-a-commit/this-command-shows-each-one"), command,
         *(Prompts.text("report-after-a-commit/the-principles-skill-is-where-to-start") if @skill)]
      end

      # The other changed members still listed, and the command that shows each, or nothing when none is.
      #: (Integer) -> Array[String]
      def listed_beside_the_waiting(others)
        return [] if others.zero?

        [*still_listed(others), Prompts.text("report-after-a-commit/this-command-shows-each-one"), command]
      end

      # The members whose audits wait on an upgrade, as rows, then each wait's line, which says how to update.
      #: (Array[Hash[String, untyped]], Array[RecordWaitingOnAnUpgrade]) -> Array[String]
      def waiting_lines(waiting, waits)
        [Prompts.text("report-after-a-commit/the-commits-changed-these-members-waiting-on-an-upgrade"),
         *rows(waiting), *waits.map(&:to_s)]
      end

      #: (Array[Hash[String, untyped]]) -> Array[String]
      def rows(members) = members.map { MemberRow.new(it).to_s }

      # The line saying how many other changed members list-member-problems still lists, or none when it lists none.
      #: (Integer) -> Array[String]
      def still_listed(others)
        return [] if others.zero?

        [Prompts.text("report-after-a-commit/others-are-still-listed",
                      count: others.to_s, members: others == 1 ? "member is" : "members are")]
      end

      #: () -> String
      def command = @invocation.in_project("list-member-problems")

      # The hook's JSON. Each field from a project file or commit is written through VisibleText already, so an
      # invisible character reaches the model as \uXXXX, not hidden in the text it reads.
      #: (String, Array[String]) -> Lines
      def reported(event, lines)
        output = { "hookSpecificOutput" => { "hookEventName" => event, "additionalContext" => lines.join("\n") } }
        Lines.new(stdout: "#{JSON.generate(output)}\n", stderr: "", status: 0)
      end
    end
  end
end

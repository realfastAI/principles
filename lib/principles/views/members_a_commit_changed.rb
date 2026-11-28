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
    # Claude Code's hooks page asks that additionalContext be "factual statements rather than imperative system
    # instructions", since imperative text can be surfaced to the user as a suspected injection (the
    # after-commit hook review, R7). So it states what the commits changed, then the one command that shows what
    # each needs before the next commit: a second pointer, the plugin's skill, left the agent choosing.
    class MembersACommitChanged
      NOTHING = Lines.new(stdout: "", stderr: "", status: 0).freeze #: Lines

      # How many other changed members list-member-problems still lists: those earlier commits changed, and those in
      # an installed plugin, which no commit changes.
      StillListed = Struct.new(:from_commits, :in_plugins) do
        #: () -> bool
        def none? = from_commits.zero? && in_plugins.zero?

        # A line for each kind still listed, or none.
        #: () -> Array[String]
        def lines
          commits = Prompts.text("report-after-a-commit/others-are-still-listed",
                                 count: from_commits.to_s, members: members(from_commits))
          plugins = Prompts.text("report-after-a-commit/plugin-members-are-still-listed",
                                 count: in_plugins.to_s, members: members(in_plugins))
          [*(commits unless from_commits.zero?), *(plugins unless in_plugins.zero?)]
        end

        private

        #: (Integer) -> String
        def members(count) = count == 1 ? "member is" : "members are"
      end

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # changed is each member the commits changed, as list-member-problems lists it; others is how many other changed
      # members it still lists. Those it marks waiting_on_an_upgrade are named apart, with the waits that say why, and
      # no audit to run; the others still listed are counted beside them too, since this copy may
      # audit those.
      #: (String, Array[Hash[String, untyped]], others: StillListed, ?waits: Array[RecordWaitingOnAnUpgrade]) -> Lines
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

      # The members to audit, as rows, then the command that shows what each needs before the next commit.
      #: (Array[Hash[String, untyped]], StillListed) -> Array[String]
      def to_audit(changed, others)
        [Prompts.text("report-after-a-commit/the-commits-changed-these-members"), *rows(changed),
         *others.lines, before_the_next_commit]
      end

      # The other changed members still listed, and the command that shows each, or nothing when none is.
      #: (StillListed) -> Array[String]
      def listed_beside_the_waiting(others)
        return [] if others.none?

        [*others.lines, before_the_next_commit]
      end

      # The one command that shows what each member needs before the next commit, list-member-problems --short.
      #: () -> String
      def before_the_next_commit
        Prompts.text("report-after-a-commit/this-command-shows-what-each-needs-before-the-next-commit",
                     command: @invocation.in_project("list-member-problems", options: ["--short"]))
      end

      # The members whose audits wait on an upgrade, as rows, then each wait's line, which says how to update.
      #: (Array[Hash[String, untyped]], Array[RecordWaitingOnAnUpgrade]) -> Array[String]
      def waiting_lines(waiting, waits)
        [Prompts.text("report-after-a-commit/the-commits-changed-these-members-waiting-on-an-upgrade"),
         *rows(waiting), *waits.map(&:to_s)]
      end

      #: (Array[Hash[String, untyped]]) -> Array[String]
      def rows(members) = members.map { MemberRow.new(it).to_s }

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

# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "problem_lines"
require_relative "visible_text"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # list-open-findings --short: the one line a session-start hook puts into the agent's context while any
    # finding is open that someone should raise, and nothing when none is. It says first to act on each that waits
    # on the agent and to raise each that waits on a person, and why, then states the facts the agent judges from,
    # how many wait on someone named or on no one and how long the oldest has, with the command that lists whom
    # each waits on.
    class OpenFindingsLine
      # The session's start the line is worded for, as Claude Code's SessionStart hook names it: startup, resume,
      # clear or compact. It says what the context holds already, and so which reply raises the findings.
      class SessionStart
        #: (String) -> void
        def initialize(source)
          @source = source
          freeze
        end

        # A resumed conversation already holds the line printed when its context began.
        #: () -> bool
        def resumed? = @source == "resume"

        # The reply that raises the findings: the first at startup, and the next once the session is under way,
        # after /clear or a compaction.
        #: () -> String
        def reply = @source == "startup" ? "first" : "next"
      end

      # The open findings as the line states them, from the plain hash a controller hands it: how many are open and
      # the oldest of all, which a resumed line names, and how many wait on someone named or on no one, with the
      # oldest of the former.
      class Waiting
        #: (Hash[String, untyped]) -> void
        def initialize(fields)
          @fields = fields
          freeze
        end

        #: () -> Integer
        def count = @fields.fetch("count")

        #: () -> Integer
        def days_open = @fields.fetch("days_open")

        #: () -> Integer
        def named = @fields.fetch("waiting_on_someone_named")

        #: () -> Integer
        def unnamed = @fields.fetch("waiting_on_no_one_named")

        # The oldest open finding of all, by principle and finding_id.
        #: () -> Hash[String, untyped]
        def oldest = @fields.slice("principle", "finding_id")
      end

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # waiting is nil when no finding is open, or the count of open findings with the oldest one's principle,
      # finding_id, days_open, how many wait on someone named and the oldest of those, or nil. not_found is each
      # open finding, by principle and finding_id, whose write-up can no longer be found where its recorded_at
      # points. source is the session's start: startup, resume, clear or compact.
      #: (Hash[String, untyped]?, ?Array[Hash[String, untyped]], ?source: String) -> Lines
      def short(waiting, not_found = [], source: "startup")
        Lines.new(stdout: lines(waiting, not_found, source:).map { "#{it}\n" }.join, stderr: "", status: 0)
      end

      # short's line, as a list of none or one, which report-at-session-start prints among its own.
      #: (Hash[String, untyped]?, ?Array[Hash[String, untyped]], ?source: String) -> Array[String]
      def lines(waiting, not_found = [], source: "startup")
        start = SessionStart.new(source)
        return [] unless waiting

        waiting = Waiting.new(waiting)
        return [resumed("#{how_long(waiting)} (#{oldest(waiting.oldest)})", not_found)] if start.resumed?

        [whole(waiting, not_found, start)]
      end

      private

      # The line with what to do about the findings, for a context that does not hold it yet: the reply that raises
      # them and why, then the facts, then the command listing them all with whom each waits on. With none naming
      # anyone, none can wait on the agent, so it says only to raise them.
      #: (Waiting, Array[Hash[String, untyped]], SessionStart) -> String
      def whole(waiting, not_found, start)
        values = { reply: start.reply, command: all,
                   facts: "#{counts(waiting)}, the oldest #{age(waiting.days_open)}.#{write_ups(not_found)}" }
        return Prompts.text("start-a-session/raise-the-open-findings-waiting-on-no-one", **values) \
          if waiting.named.zero?

        Prompts.text("start-a-session/act-on-the-open-findings", whom: whom(waiting), **values)
      end

      # The command listing every open finding, a line each.
      #: () -> String
      def all = @invocation.in_project("list-open-findings", options: ["--lines"])

      # Whom the findings the agent raises wait on, while some name someone, once it acts on those that wait on
      # itself: a person, and no one, if any names none, since nothing else will raise those either.
      #: (Waiting) -> String
      def whom(waiting) = "a person#{" or on no one" if waiting.unnamed.positive?}"

      # How many wait on someone named and on no one, the first counted as the sentence's subject.
      #: (Waiting) -> String
      def counts(waiting)
        unnamed = waiting.unnamed
        return "#{counted(unnamed)} on no one named" if waiting.named.zero?

        "#{counted(waiting.named)} on someone named#{", #{unnamed} on no one" if unnamed.positive?}"
      end

      # How long a finding has gone unraised, in whole days.
      #: (Integer) -> String
      def age(days) = "open #{days} #{days == 1 ? "day" : "days"}"

      # How many open findings wait, as the subject of the sentence saying on whom.
      #: (Integer) -> String
      def counted(count) = count == 1 ? "1 open finding waits" : "#{count} open findings wait"

      # A resumed session's line: its conversation already holds the line printed when that context began, so this
      # one gives the facts and where the instructions are, not the instructions again.
      #: (String, Array[Hash[String, untyped]]) -> String
      def resumed(findings, not_found)
        Prompts.text("start-a-session/see-the-earlier-line",
                     findings: findings, write_ups: write_ups(not_found),
                     command: @invocation.in_project("list-open-findings", options: ["--short"]))
      end

      # The sentence naming the write-ups that can no longer be found, the first by its principle and id, or
      # nothing when every pointer resolves, so the usual line is unchanged.
      #: (Array[Hash[String, untyped]]) -> String
      def write_ups(not_found)
        first = not_found.first or return ""
        named = "#{first.fetch("principle")} #{VisibleText.new(first.fetch("finding_id"))}"
        return " The write-up of #{named} cannot be found where its recorded_at points, and the list says why." \
          if not_found.one?

        " The write-ups of #{not_found.length} findings, the first #{named}, cannot be found where their " \
          "recorded_at points, and the list says why."
      end

      # How many findings are open and how long the oldest has waited.
      #: (Waiting) -> String
      def how_long(waiting) = "#{still_open(waiting.count)}#{waited(waiting)}"

      #: (Integer) -> String
      def still_open(count)
        count == 1 ? "1 audit finding is still open, " : "#{count} audit findings are still open, the oldest "
      end

      #: (Waiting) -> String
      def waited(waiting)
        days = waiting.days_open
        return "for less than a day" if days < 1

        "for #{days} #{days == 1 ? "day" : "days"}"
      end

      # The oldest finding's principle and id, which is free text and so escaped.
      #: (Hash[String, untyped]) -> String
      def oldest(waiting) = "#{waiting.fetch("principle")} #{VisibleText.new(waiting.fetch("finding_id"))}"
    end
  end
end

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
    # finding is open, and nothing when none is. It says how many wait, how long the oldest has, what that
    # one waits on, and the command that lists them all, worded as something to act on.
    class OpenFindingsLine
      # A waits_on longer than this is cut, so the line stays one short line.
      WAITS_ON_LIMIT = 80

      # The session's start the line is worded for, as Claude Code's SessionStart hook names it: startup, resume,
      # clear or compact. It says what the context holds already, and so when to raise the findings.
      class SessionStart
        #: (String) -> void
        def initialize(source)
          @source = source
          freeze
        end

        # A resumed conversation already holds the line printed when its context began.
        #: () -> bool
        def resumed? = @source == "resume"

        # When to raise the findings: before the user's first task at startup, and at the next pause once the
        # session is under way, after /clear or a compaction.
        #: () -> String
        def raise_when
          return Prompts.text("start-a-session/raise-them-before-the-first-task") if startup?

          Prompts.text("start-a-session/raise-them-at-the-next-pause")
        end

        private

        #: () -> bool
        def startup? = @source == "startup"
      end

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # waiting is nil when no finding is open, or the count of open findings with the oldest one's principle,
      # finding_id, days_open and, when it says, waits_on. not_found is each open finding, by principle and
      # finding_id, whose write-up can no longer be found where its recorded_at points. source is the
      # session's start: startup, resume, clear or compact.
      #: (Hash[String, untyped]?, ?Array[Hash[String, untyped]], ?source: String) -> Lines
      def short(waiting, not_found = [], source: "startup")
        Lines.new(stdout: lines(waiting, not_found, source:).map { "#{it}\n" }.join, stderr: "", status: 0)
      end

      # short's line, as a list of none or one, which report-at-session-start prints among its own.
      #: (Hash[String, untyped]?, ?Array[Hash[String, untyped]], ?source: String) -> Array[String]
      def lines(waiting, not_found = [], source: "startup")
        waiting ? [line(waiting, not_found, SessionStart.new(source))] : []
      end

      private

      #: (Hash[String, untyped], Array[Hash[String, untyped]], SessionStart) -> String
      def line(waiting, not_found, start)
        return resumed("#{how_long(waiting)} (#{oldest(waiting)})", not_found) if start.resumed?

        whole(waiting, not_found, start)
      end

      # The line with what to do about the findings, for a context that does not hold it yet.
      #: (Hash[String, untyped], Array[Hash[String, untyped]], SessionStart) -> String
      def whole(waiting, not_found, start)
        count = waiting.fetch("count")
        Prompts.text("start-a-session/act-on-the-open-findings",
                     when: start.raise_when,
                     findings: "#{how_long(waiting)} (#{named(waiting)})",
                     no_one_named: no_one_named(count, waiting.fetch("waiting_on_no_one_named", 0)),
                     write_ups: write_ups(not_found),
                     each: count == 1 ? "it" : "each",
                     command: @invocation.in_project("list-open-findings", options: ["--lines"]))
      end

      # A resumed session's line: its conversation already holds the line printed when that context began, so this
      # one gives the facts and where the instructions are, not the instructions again.
      #: (String, Array[Hash[String, untyped]]) -> String
      def resumed(findings, not_found)
        Prompts.text("start-a-session/see-the-earlier-line",
                     findings: findings, write_ups: write_ups(not_found),
                     command: @invocation.in_project("list-open-findings", options: ["--short"]))
      end

      # How many of several open findings are deferred with no waits_on, since the line names only the oldest's. One
      # open finding's own name already shows whether it does, so its line says nothing more.
      #: (Integer, Integer) -> String
      def no_one_named(count, unnamed)
        return "" if count == 1 || unnamed.zero?
        return " All #{count} have no waits_on." if unnamed == count

        " #{unnamed} #{unnamed == 1 ? "has" : "have"} no waits_on."
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
      #: (Hash[String, untyped]) -> String
      def how_long(waiting) = "#{counted(waiting.fetch("count"))}#{waited(waiting)}"

      #: (Integer) -> String
      def counted(count)
        count == 1 ? "1 audit finding is still open, " : "#{count} audit findings are still open, the oldest "
      end

      #: (Hash[String, untyped]) -> String
      def waited(waiting)
        days = waiting.fetch("days_open")
        return "for less than a day" if days < 1

        "for #{days} #{days == 1 ? "day" : "days"}"
      end

      # The oldest finding's principle and id, and what it waits on, cut when long. The id and waits_on are free
      # text, so each is cut by characters first and then escaped, which may run past the limit to show them.
      #: (Hash[String, untyped]) -> String
      def named(waiting)
        named = oldest(waiting)
        waits_on = waiting["waits_on"] or return named
        waits_on = closed("#{whole_words(waits_on[0, WAITS_ON_LIMIT - 3].to_s)}...") if waits_on.length > WAITS_ON_LIMIT
        "#{named}, waits on: #{VisibleText.new(waits_on)}"
      end

      # A cut waits_on up to its last whole word, so it never ends in part of one, or as cut when it is one
      # word, which has no boundary to cut at.
      #: (String) -> String
      def whole_words(cut)
        boundary = cut.rindex(" ") or return cut
        cut[0, boundary].to_s
      end

      # The oldest finding's principle and id, which is free text and so escaped.
      #: (Hash[String, untyped]) -> String
      def oldest(waiting) = "#{waiting.fetch("principle")} #{VisibleText.new(waiting.fetch("finding_id"))}"

      # A cut waits_on with a ")" for each "(" the cut left open, so the line's own parenthesis still reads as
      # closing the finding's name.
      #: (String) -> String
      def closed(cut)
        cut + (")" * [cut.count("(") - cut.count(")"), 0].max)
      end
    end
  end
end

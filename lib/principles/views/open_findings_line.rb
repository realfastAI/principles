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
    # finding is open that someone should raise, and nothing when none is. It states the facts the agent judges
    # from, how many wait on someone named or on no one, whom the oldest of the former waits on and for how long,
    # and git's user name, then says to raise each that waits on its user, and why, with the command that lists
    # them all.
    class OpenFindingsLine
      # A waits_on longer than this is cut, so the line stays one short line.
      WAITS_ON_LIMIT = 80

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

        #: () -> Integer
        def to_raise = @fields.fetch("to_raise")

        # Whether the one finding to raise is one waiting on someone named, whose own line names its need.
        #: () -> bool
        def alone? = to_raise == 1 && named == 1

        # The oldest open finding of all, by principle and finding_id.
        #: () -> Hash[String, untyped]
        def oldest = @fields.slice("principle", "finding_id")

        # The oldest finding waiting on someone named, by principle, finding_id and waits_on, or nil.
        #: () -> Hash[String, untyped]?
        def oldest_named = @fields["oldest_waiting_on_someone"]
      end

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # waiting is nil when no finding is open, or the count of open findings with the oldest one's principle,
      # finding_id, days_open, how many wait on someone named and the oldest of those, or nil. not_found is each
      # open finding, by principle and finding_id, whose write-up can no longer be found where its recorded_at
      # points. source is the session's start: startup, resume, clear or compact. user_name is git's, or nil.
      #: (Hash[String, untyped]?, ?Array[Hash[String, untyped]], ?source: String, ?user_name: String?) -> Lines
      def short(waiting, not_found = [], source: "startup", user_name: nil)
        Lines.new(stdout: lines(waiting, not_found, source:, user_name:).map { "#{it}\n" }.join, stderr: "", status: 0)
      end

      # short's line, as a list of none or one, which report-at-session-start prints among its own.
      #: (Hash[String, untyped]?, ?Array[Hash[String, untyped]], ?source: String, ?user_name: String?) -> Array[String]
      def lines(waiting, not_found = [], source: "startup", user_name: nil)
        start = SessionStart.new(source)
        return [] unless waiting

        waiting = Waiting.new(waiting)
        return [resumed("#{how_long(waiting)} (#{oldest(waiting.oldest)})", not_found)] if start.resumed?
        return [] if waiting.to_raise.zero?

        [whole(waiting, not_found, start, user_name)]
      end

      private

      # The line with what to do about the findings, for a context that does not hold it yet: the facts, then the
      # reply that raises them and why, then the command listing them all, which one finding's own need replaces.
      #: (Waiting, Array[Hash[String, untyped]], SessionStart, String?) -> String
      def whole(waiting, not_found, start, user_name)
        Prompts.text("start-a-session/act-on-the-open-findings",
                     facts: "#{waiting_on_someone(waiting)}#{no_one_named(waiting)}#{write_ups(not_found)}" \
                            "#{git_user(user_name) unless waiting.named.zero?}",
                     raise: raise_which(waiting), reply: start.reply, command: waiting.alone? ? "" : " All: #{all}")
      end

      # The command listing every open finding, a line each.
      #: () -> String
      def all = @invocation.in_project("list-open-findings", options: ["--lines"])

      # Which findings the agent raises: the one, if it waits on its user, or each that does, with those waiting on
      # no one, or each when none names anyone.
      #: (Waiting) -> String
      def raise_which(waiting)
        return "If it waits on your user, raise it" if waiting.alone?
        return "Raise each" if waiting.named.zero?

        "Raise each that waits on your user#{" or on no one" if waiting.unnamed.positive?}"
      end

      # The sentence naming the oldest finding that waits on someone named, and whom, counting them when several do.
      #: (Waiting) -> String
      def waiting_on_someone(waiting)
        oldest = waiting.oldest_named or return ""
        need = need(oldest.fetch("waits_on"))
        need = "#{need}." unless need.end_with?(".")
        named = "#{oldest(oldest)}, #{age(oldest.fetch("days_open"))},"
        return "Open finding #{named} waits on: #{need}" if waiting.named == 1

        "#{counted(waiting.named)} on someone; the oldest, #{named} waits on: #{need}"
      end

      # How long a finding has gone unraised, in whole days.
      #: (Integer) -> String
      def age(days) = "open #{days} #{days == 1 ? "day" : "days"}"

      # The sentence counting the findings deferred with no waits_on, after any naming someone.
      #: (Waiting) -> String
      def no_one_named(waiting)
        unnamed = waiting.unnamed
        return "" if unnamed.zero?
        return " #{unnamed} #{unnamed == 1 ? "waits" : "wait"} on no one named." if waiting.named.positive?

        "#{counted(unnamed)} on no one named."
      end

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

      # git's user name as a fact, for the agent to judge whether the person a finding waits on is its user.
      #: (String?) -> String
      def git_user(name)
        return " git has no user.name set." unless name

        " git's user.name is #{VisibleText.new(name)}."
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

      # A finding's waits_on, cut when long. It is free text, so it is cut by characters first and then escaped,
      # which may run past the limit to show it.
      #: (String) -> String
      def need(waits_on)
        waits_on = closed("#{whole_words(waits_on[0, WAITS_ON_LIMIT - 3].to_s)}...") if waits_on.length > WAITS_ON_LIMIT
        VisibleText.new(waits_on).to_s
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

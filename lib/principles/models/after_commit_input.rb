# typed: strict
# frozen_string_literal: true

require "json"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The JSON a host hands its hook after each shell call, as report-after-commit reads it: the event it ran on,
    # when the call started, and the directories whose repositories the call may have committed in. Input it cannot
    # read names no event, so the hook reports nothing rather than refuse.
    class AfterCommitInput
      # The events a host runs the after-commit hook on: Claude Code both, Codex PostToolUse alone.
      EVENTS = %w[PostToolUse PostToolUseFailure].freeze #: Array[String]
      # How many seconds after the call ended a host may start the hook on a loaded machine. The hook cannot tell a
      # late start from a long call, so a move up to this many seconds, and one more, before the call is reported
      # again: a repeat costs a report, where a miss leaves a commit's change unseen until the next session start.
      LATE_START_S = 5
      # Where a cd or a git -C may start: the command's start, or after ;, &, |, ( or ).
      SEGMENTS = /[;&|()]/ #: Regexp
      # A cd or git -C and its target: one word, or one layer of matching double or single quotes.
      TARGET = /\A\s*(cd|git\s+-C)\s+("[^"]*"|'[^']*'|\S+)/ #: Regexp
      # A target holding any of these, or starting with -, is not read, so no expansion is guessed at.
      UNREAD = /["'$\\`]/ #: Regexp

      # The event the host ran the hook on, or nil when there is nothing to report.
      #: String?
      attr_reader :event

      # The second the call started, or earlier: see LATE_START_S.
      #: Integer
      attr_reader :started

      # The hook's input as the process it runs in reads it, the one owner of that reading for the executable, before
      # the rest of this tool loads, and for the command: started at clock, unless environment's PRINCIPLES_HOOK_NOW,
      # a test seam no session sets, gives the second; with home as ~; and for input naming no cwd, the session's
      # directory, as Claude Code names it in CLAUDE_PROJECT_DIR, or pwd.
      #: (String, Hash[String, String], clock: Integer, home: String, pwd: String) -> AfterCommitInput
      def self.read(text, environment, clock:, home:, pwd:)
        new(text, now: Integer(environment.fetch("PRINCIPLES_HOOK_NOW", clock)), home: home,
                  fallback: environment.fetch("CLAUDE_PROJECT_DIR", pwd))
      end

      # now is the second the hook started; home is the home directory a leading ~ names; fallback the session's
      # directory, for input naming no cwd.
      #: (String, now: Integer, home: String, fallback: String) -> void
      def initialize(text, now:, home:, fallback:)
        given = parsed(text)
        @event = EVENTS.find { it == given["hook_event_name"] } #: String?
        @started = started_before(now, given["duration_ms"]) #: Integer
        @cwd = text(given["cwd"]) || fallback #: String
        tool_input = given["tool_input"]
        @command = (text(tool_input["command"]) if tool_input.is_a?(Hash)) || "" #: String
        @home = home
        freeze
      end

      # The call's cwd, then each directory its command changed into with cd or ran git in with git -C, in order,
      # each resolved from the cd before it. Targets are read by position, not by the shell's rules, so a cd in a
      # subshell is taken as if it ran in turn, and only the first -C of a git is read.
      #: () -> Array[String]
      def directories
        from = @cwd
        targets = @command.split(SEGMENTS).filter_map do |segment|
          word, target = segment.match(TARGET)&.captures
          next unless word && target

          resolved = resolved(unquoted(target), from) or next
          from = resolved if word == "cd"
          resolved
        end
        [@cwd, *targets]
      end

      private

      # When a call that ended by now started, from its duration in milliseconds, rounded up to the second, and a
      # second earlier, since a file's time and this clock both count whole seconds, and LATE_START_S earlier
      # still. A duration that is not a positive whole number, or none, as Codex sends, reads as no time.
      #: (Integer, untyped) -> Integer
      def started_before(now, duration)
        duration = 0 unless duration.is_a?(Integer) && duration.positive?
        now - ((duration + 999) / 1000) - 1 - LATE_START_S
      end

      # A text field's value, or nil when it gives none.
      #: (untyped) -> String?
      def text(given) = given.is_a?(String) && !given.empty? ? given : nil

      #: (String) -> String
      def unquoted(target)
        quoted = target.length > 1 && %w[" '].include?(target[0]) && target[0] == target[-1]
        quoted ? target[1...-1].to_s : target
      end

      # target as a path from the directory from, or nil when it is not read.
      #: (String, String) -> String?
      def resolved(target, from)
        return if target.empty? || target.start_with?("-") || target.match?(UNREAD)
        return target if target.start_with?("/")
        return @home if target == "~"
        return "#{@home}/#{target.delete_prefix("~/")}" if target.start_with?("~/")

        "#{from}/#{target}"
      end

      #: (String) -> Hash[String, untyped]
      def parsed(text)
        given = JSON.parse(text)
        given.is_a?(Hash) ? given : {}
      rescue JSON::ParserError
        {}
      end
    end
  end
end

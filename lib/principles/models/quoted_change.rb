# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member_lines"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A one-member audit's change as its answer quotes it: a line of the member before the change and one after,
    # each a whole line of its side or a fragment long enough to show the edit that only its side reads.
    class QuotedChange
      # One side of the change a quote is checked against: the member's lines then, and when they read.
      class SideOfTheChange
        #: String
        attr_reader :reads_at

        #: (Array[String], String) -> void
        def initialize(lines, reads_at)
          @lines = lines.map(&:chomp) #: Array[String]
          @reads_at = reads_at
          freeze
        end

        #: (String) -> bool
        def whole_line?(quote) = @lines.include?(quote)

        #: (String) -> bool
        def holds?(text) = @lines.any? { |line| line.include?(text) }

        # Its first line the other side lacks, or "" when it has none, as after a pure insertion on the other side.
        #: (SideOfTheChange) -> String
        def first_line_absent_from(other) = @lines.find { |line| !other.whole_line?(line) } || ""
      end

      # The fewest characters a quoted fragment of a line may have, so it shows which edit was read.
      FRAGMENT_LENGTH = 30

      # The longest changed line the hint gives whole, beyond which it gives the span the edit changed.
      LONG_LINE = 200

      # lines holds the member's lines at its baseline commit and at HEAD; member_id names it in a refusal.
      #: (MemberLines, member_id: String) -> void
      def initialize(lines, member_id:)
        @then = SideOfTheChange.new(lines.at_baseline, "before the change") #: SideOfTheChange
        @now = SideOfTheChange.new(lines.now, "at HEAD") #: SideOfTheChange
        @member_id = member_id
        freeze
      end

      # The first line on each side the other lacks, which the request hints the quotes from; of a pair with a
      # line over LONG_LINE characters, the span each side's edit changed, so a small edit is found without comparing
      # two long lines by eye, and the request does not carry them again.
      #: () -> Hash[String, String]
      def first_changed_lines
        old_line = @then.first_line_absent_from(@now)
        new_line = @now.first_line_absent_from(@then)
        whole = { "old_line" => old_line, "new_line" => new_line }
        return whole if whole.values.all? { it.length <= LONG_LINE }

        { "old_line" => changed_span(old_line, new_line, @then, @now),
          "new_line" => changed_span(new_line, old_line, @now, @then) }
      end

      # Refuses an old_line not found before the change, or a new_line not found after it.
      #: (old_line: String, new_line: String) -> void
      def check(old_line:, new_line:)
        quoted(old_line, @then, @now)
        quoted(new_line, @now, @then)
      end

      private

      # line's characters between those it shares with other_line from the start and from the end, with
      # FRAGMENT_LENGTH more on each side, widened to whole words, when that fragment is a quote only side holds; else
      # the whole line.
      #: (String, String, SideOfTheChange, SideOfTheChange) -> String
      def changed_span(line, other_line, side, other)
        edit = edited(line, other_line)
        from = word_start(line, [edit.begin - FRAGMENT_LENGTH, 0].max)
        span = line[from...word_end(line, edit.end + FRAGMENT_LENGTH)].to_s
        only_on?(span, side, other) ? span : line
      end

      # The start of the word at index in line, when it starts within FRAGMENT_LENGTH before it; else index, so a
      # span of a line without spaces keeps its context.
      #: (String, Integer) -> Integer
      def word_start(line, index)
        return index if index.zero?

        start = (line.rindex(" ", index - 1) || -1) + 1
        index - start <= FRAGMENT_LENGTH ? start : index
      end

      # The end of the word at index in line, when it ends within FRAGMENT_LENGTH after it; else index.
      #: (String, Integer) -> Integer
      def word_end(line, index)
        finish = line.index(" ", index) || line.length
        finish - index <= FRAGMENT_LENGTH ? finish : index
      end

      # The characters of line between those it shares with other_line from the start and from the end, which never
      # overlap, as an insertion repeating its neighbour would make them.
      #: (String, String) -> Range[Integer]
      def edited(line, other_line)
        head = common_length(line, other_line)
        tail = common_length(line[head..].to_s.reverse, other_line[head..].to_s.reverse)
        head...(line.length - tail)
      end

      # How many characters two strings share from their start.
      #: (String, String) -> Integer
      def common_length(one, other) = one.each_char.zip(other.each_char).take_while { |a, b| a == b }.length

      # A quote is a whole line, or a fragment long enough to show the edit, that only this side reads; or "" when
      # this side has no line the other lacks, as before a pure insertion.
      #: (String, SideOfTheChange, SideOfTheChange) -> void
      def quoted(line, side, other)
        return if line == side.first_line_absent_from(other)
        return if !line.empty? && only_on?(line, side, other)

        raise Error.new("quote_not_found",
                        "#{line.inspect} is not a line of #{@member_id} #{side.reads_at} that the change touched",
                        "Quote a whole line of the member as it reads #{side.reads_at}, as first_changed_lines " \
                        "shows, or at least #{FRAGMENT_LENGTH} characters of one that the member #{other.reads_at} " \
                        "does not hold; quote \"\" only where first_changed_lines does.")
      end

      # Whether a quote is a whole line of side, or a fragment of at least FRAGMENT_LENGTH, that other does not hold.
      #: (String, SideOfTheChange, SideOfTheChange) -> bool
      def only_on?(line, side, other)
        (side.whole_line?(line) && !other.whole_line?(line)) ||
          (line.length >= FRAGMENT_LENGTH && side.holds?(line) && !other.holds?(line))
      end
    end
  end
end

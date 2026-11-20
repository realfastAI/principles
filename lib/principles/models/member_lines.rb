# typed: strict
# frozen_string_literal: true

require_relative "changed_regions"
require_relative "line_diff"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # A member's own lines at its baseline and now, as a one-member audit's request shows them, so the agent reads
    # the change its quotes are checked against and not the rest of an edit to the file. A long member, such
    # as a whole file, shows only its changed region: the lines between its first and last difference, with a little
    # context. Past a limit even that is counted instead, so a request never carries a file twice.
    class MemberLines
      # The most lines either side shows: a section or a passage fits, and so does the changed region of most edits
      # to a whole file. A first guess, for an alpha test to confirm.
      SHOWN_AT_MOST = 80

      # The most bytes both sides together show whole: a 4 KB acknowledgement less its 2.7 KB of other fields,
      # so a short file of long lines shows its changed region and not itself twice.
      SHOWN_BYTES_AT_MOST = 1300

      # The most unchanged lines shown on each side of a changed region, as git shows by default; fewer
      # when these would pass SHOWN_BYTES_AT_MOST.
      CONTEXT_LINES = 3

      # The most shown around a one-line change, whose edit first_changed_lines already gives.
      ONE_LINE_CONTEXT_LINES = 1

      # Each line is kept without its line ending, so a line the agent copies from the request is a whole line it
      # can quote.
      #: (at_baseline: Array[String], now: Array[String]) -> void
      def initialize(at_baseline:, now:)
        @at_baseline = at_baseline.map(&:chomp) #: Array[String]
        @now = now.map(&:chomp) #: Array[String]
        freeze
      end

      # The member's lines at the baseline and now, each without its line ending.
      #: Array[String]
      attr_reader :at_baseline

      #: Array[String]
      attr_reader :now

      # Whether its lines now read otherwise than at the baseline, as a prior finding's evidence item says.
      #: () -> bool
      def changed? = @at_baseline != @now

      # Both sides' lines while each is at most SHOWN_AT_MOST lines and together at most SHOWN_BYTES_AT_MOST less
      # taken, the bytes a request's other parts take beyond its usual ones, as a checked member's check_result
      # template does; else their changed region, with where it starts within the member and each side's
      # length; else how many lines each side has.
      #: (?taken: Integer) -> Hash[String, untyped]
      def shown(taken: 0)
        budget = SHOWN_BYTES_AT_MOST - taken
        sides = { "at_baseline" => @at_baseline, "now" => @now }
        return sides if within_line_limit?(sides.values) && bytes(sides.values) <= budget

        counts = sides.transform_values(&:length)
        regions = regions_within(budget)
        return { "omitted" => "too_long", "lines" => counts } unless within_line_limit?(regions.lines)

        { **regions.shown, "lines" => counts }
      end

      private

      # How many bytes the sides' lines hold together.
      #: (Array[Array[String]]) -> Integer
      def bytes(sides) = sides.sum { |lines| lines.sum(&:bytesize) }

      #: (Array[Array[String]]) -> bool
      def within_line_limit?(sides)
        sides.all? { |lines| lines.length <= SHOWN_AT_MOST }
      end

      # The changed regions with the most context, up to CONTEXT_LINES, whose lines fit budget; with none when no
      # context fits, since the changed lines are what is judged, and then the sides first_changed_lines' span and
      # read_the_change stand in for left out.
      #: (Integer) -> ChangedRegions
      def regions_within(budget)
        hunks = LineDiff.new(@at_baseline, @now).hunks
        all = most_context(hunks).downto(0).map { ChangedRegions.new(@at_baseline, @now, hunks: hunks, context: it) }
        all.find { bytes(it.lines) <= budget } || all.fetch(-1).with_sides_left_out
      end

      # ONE_LINE_CONTEXT_LINES when one run changed one line at most on each side, else CONTEXT_LINES.
      #: (Array[LineDiff::Hunk]) -> Integer
      def most_context(hunks)
        one_line = ChangedRegions.new(@at_baseline, @now, hunks: hunks, context: 0).one_line?
        one_line ? ONE_LINE_CONTEXT_LINES : CONTEXT_LINES
      end
    end

    # A member that cannot be placed in its file at the last full audit's commit, as after a move: the commit lacks
    # the file, or the member's reference finds nothing there. An empty side would say it was empty.
    class MemberLinesNotFoundAtLastAudit
      #: () -> void
      def initialize
        freeze
      end

      # That fact, in place of the lines.
      #: () -> Hash[String, untyped]
      def shown
        { "omitted" => "not_found_at_last_audit" }
      end
    end
  end
end

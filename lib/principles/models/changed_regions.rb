# typed: strict
# frozen_string_literal: true

require_relative "line_diff"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # A long member's changed lines as a request shows them: each run of changed lines with up to context unchanged
    # lines around it, as git shows a hunk, runs whose context would meet joined into one region, and each later
    # region counting the unchanged lines skipped before it, so two distant edits never show the text between them.
    class ChangedRegions
      #: (Array[String], Array[String], hunks: Array[LineDiff::Hunk], context: Integer,
      #|  ?left_out: Array[String]) -> void
      def initialize(at_baseline, now, hunks:, context:, left_out: [])
        @sides = { "at_baseline" => at_baseline, "now" => now } #: Hash[String, Array[String]]
        @context = context
        @runs = joined(hunks) #: Array[LineDiff::Hunk]
        @left_out = left_out
        freeze
      end

      # The lines each side shows, across every region, none for a side left out.
      #: () -> Array[Array[String]]
      def lines
        @sides.map { |name, side| @left_out.include?(name) ? [] : @runs.flat_map { side[around(it, name)] || [] } }
      end

      # Whether one region changed at most one line on each side, whose change first_changed_lines' span shows whole.
      #: () -> bool
      def one_line? = @runs.one? && lines.all? { it.length <= 1 }

      # These regions with their baseline side's lines left out, saying so, and their side now too when one_line?; the
      # side now of a longer change holds lines no hint shows, so it stays.
      #: () -> ChangedRegions
      def with_sides_left_out
        left_out = one_line? ? @sides.keys : ["at_baseline"]
        ChangedRegions.new(@sides.fetch("at_baseline"), @sides.fetch("now"), hunks: @runs, context: @context,
                                                                             left_out: left_out)
      end

      # One region as changed_region, or several as changed_regions.
      #: () -> Hash[String, untyped]
      def shown
        regions = @runs.each_with_index.map { |hunk, index| region(hunk, index.positive? ? @runs[index - 1] : nil) }
        return { "changed_region" => regions.fetch(0) } if regions.one?

        { "changed_regions" => regions }
      end

      private

      # Each run of changed lines in hunks, joined to the one before it when their context would meet or overlap.
      #: (Array[LineDiff::Hunk]) -> Array[LineDiff::Hunk]
      def joined(hunks)
        found = [] #: Array[LineDiff::Hunk]
        hunks.each do |hunk|
          last = found.last
          next found << hunk unless last && gap(last, hunk) <= 2 * @context

          found[-1] = LineDiff::Hunk.new(last.at_baseline.begin...hunk.at_baseline.end, last.now.begin...hunk.now.end)
        end
        found
      end

      # The unchanged lines between two runs, the same on both sides.
      #: (LineDiff::Hunk, LineDiff::Hunk) -> Integer
      def gap(before, after) = after.at_baseline.begin - before.at_baseline.end

      #: (LineDiff::Hunk, LineDiff::Hunk?) -> Hash[String, untyped]
      def region(hunk, before)
        skipped = before ? { "unchanged_lines_skipped" => gap(before, hunk) - (2 * @context) } : {}
        { **skipped, "context_lines" => @context, **@sides.to_h { |name, side| [name, side_of(hunk, name, side)] } }
      end

      # One side of a region: the 1-based line it starts at, and its lines, or that they are left out.
      #: (LineDiff::Hunk, String, Array[String]) -> Hash[String, untyped]
      def side_of(hunk, name, side)
        shown = around(hunk, name)
        from = { "from_line" => shown.begin + 1 }
        @left_out.include?(name) ? { **from, "omitted" => "too_long" } : { **from, "lines" => side[shown] || [] }
      end

      # The lines a run takes on one side with context lines either side, within that side.
      #: (LineDiff::Hunk, String) -> Range[Integer]
      def around(hunk, name)
        changed = name == "now" ? hunk.now : hunk.at_baseline
        [changed.begin - @context, 0].max...[changed.end + @context, @sides.fetch(name).length].min
      end
    end
  end
end

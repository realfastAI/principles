# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # Where two versions of a member's lines differ: each run of lines one side changed, in order, as a line diff finds
    # them by their longest common subsequence. The lines both sides share from the start and from the end are never
    # part of a run, so the first run starts at the same line on both sides.
    class LineDiff
      # One run of changed lines: the 0-based, end-exclusive range each side's changed lines take, empty on a side
      # that only the other side's lines were added to.
      Hunk = Struct.new(:at_baseline, :now)

      # The longest run of lines two sides hold in the same order, as the index on each side of each of its lines.
      class CommonLines
        #: (Array[String], Array[String]) -> void
        def initialize(one, other)
          @one = one
          @other = other
          freeze
        end

        #: () -> Array[[Integer, Integer]]
        def pairs
          longest = table
          at = [0, 0] #: [Integer, Integer]
          found = [] #: Array[[Integer, Integer]]
          while at[0] < @one.length && at[1] < @other.length
            found << at if @one[at[0]] == @other[at[1]]
            at = next_from(longest, *at)
          end
          found
        end

        private

        # The length of the longest common run from each pair of indices to both ends.
        #: () -> Array[Array[Integer]]
        def table
          longest = Array.new(@one.length + 1) { Array.new(@other.length + 1, 0) }
          (@one.length - 1).downto(0) do |one_at|
            row = longest.fetch(one_at)
            (@other.length - 1).downto(0) { |other_at| row[other_at] = length_at(longest, one_at, other_at) }
          end
          longest
        end

        #: (Array[Array[Integer]], Integer, Integer) -> Integer
        def length_at(longest, one_at, other_at)
          return cell(longest, one_at + 1, other_at + 1) + 1 if @one[one_at] == @other[other_at]

          [cell(longest, one_at + 1, other_at), cell(longest, one_at, other_at + 1)].max.to_i
        end

        # The indices after one_at and other_at along the longest common run.
        #: (Array[Array[Integer]], Integer, Integer) -> [Integer, Integer]
        def next_from(longest, one_at, other_at)
          return [one_at + 1, other_at + 1] if @one[one_at] == @other[other_at]

          skip_one = cell(longest, one_at + 1, other_at) >= cell(longest, one_at, other_at + 1)
          skip_one ? [one_at + 1, other_at] : [one_at, other_at + 1]
        end

        #: (Array[Array[Integer]], Integer, Integer) -> Integer
        def cell(longest, one_at, other_at) = longest.fetch(one_at).fetch(other_at)
      end

      #: (Array[String], Array[String]) -> void
      def initialize(at_baseline, now)
        @at_baseline = at_baseline
        @now = now
        freeze
      end

      # Each run of changed lines, in order; none when the sides read the same.
      #: () -> Array[Hunk]
      def hunks
        from = [0, 0] #: [Integer, Integer]
        (matched_pairs + [[@at_baseline.length, @now.length]]).each_with_object([]) do |(one, other), found|
          found << Hunk.new(from[0]...one, from[1]...other) if [one, other] != from
          from = [one + 1, other + 1]
        end
      end

      private

      # The index on each side of each line both sides keep, in order: those they share from the start and the end,
      # and between them the longest common run.
      #: () -> Array[[Integer, Integer]]
      def matched_pairs
        head = common_length(@at_baseline, @now)
        tail = common_length(@at_baseline.drop(head).reverse, @now.drop(head).reverse)
        (0...head).map { [it, it] } + matched_between(head, tail) +
          tail.downto(1).map { [@at_baseline.length - it, @now.length - it] }
      end

      # The longest common run of the lines after the head lines and before the tail lines both sides share.
      #: (Integer, Integer) -> Array[[Integer, Integer]]
      def matched_between(head, tail)
        one = @at_baseline[head...(@at_baseline.length - tail)].to_a
        other = @now[head...(@now.length - tail)].to_a
        CommonLines.new(one, other).pairs.map { |one_at, other_at| [one_at + head, other_at + head] }
      end

      # How many lines two sides share from their start.
      #: (Array[String], Array[String]) -> Integer
      def common_length(one, other)
        one.zip(other).take_while { |line, other_line| line == other_line && !other_line.nil? }.length
      end
    end
  end
end

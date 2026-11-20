# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The lines a member spans in its file, first to last, as a LocatedText gives them, and whether the member is
    # its whole file, so two members' spans are compared in one place.
    class LineSpan
      #: Integer
      attr_reader :first_line, :last_line

      #: (Integer, Integer, ?whole_file: bool) -> void
      def initialize(first_line, last_line, whole_file: false)
        @first_line = first_line
        @last_line = last_line
        @whole_file = whole_file
        freeze
      end

      # Whether the two spans share a line.
      #: (LineSpan) -> bool
      def shares_a_line_with?(other)
        first_line <= other.last_line && other.first_line <= last_line
      end

      # Inclusive spans meet at consecutive lines in either order, without an overlap or a gap.
      #: (LineSpan) -> bool
      def consecutive_with?(other)
        last_line + 1 == other.first_line || other.last_line + 1 == first_line
      end

      # Whether every line of other is one of this span's lines. Lines are not text: where the two share a first or
      # last line, a passage can start or end partway through it, so this span may not hold all of other's text.
      #: (LineSpan) -> bool
      def holds?(other)
        first_line <= other.first_line && other.last_line <= last_line
      end

      # Whether this span surely holds all of other's text: it holds other's lines and is a whole file, which holds
      # every line's text, where a passage may start or end partway through a line.
      #: (LineSpan) -> bool
      def holds_all_text_of?(other)
        @whole_file && holds?(other)
      end

      # Whether the two spans begin and end on the same lines. Equal lines are not equal text: a passage can end
      # within its last line.
      #: (LineSpan) -> bool
      def same_lines_as?(other)
        first_line == other.first_line && last_line == other.last_line
      end
    end
  end
end

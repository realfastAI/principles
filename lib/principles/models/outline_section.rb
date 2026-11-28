# typed: strict
# frozen_string_literal: true

require_relative "outline_item"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One heading of a candidate file's outline and the top-level list items under it, with the lines of the file it
    # spans, so an outline whose items are cut can say where to read them back.
    class OutlineSection
      # The most items printed under one heading; a longer list says how many more it holds.
      MOST_ITEMS = 20
      # The most characters of an item printed, cut back to a whole word.
      ITEM_CHARACTERS = 60
      # A heading's marks, as many as its level.
      MARKS = /\A#+/

      # The heading as Markdown; nil for the items before a file's first heading.
      #: String?
      attr_reader :heading

      # The file's lines the section spans, from its heading, counted from 1.
      #: Integer
      attr_reader :first_line

      #: Integer
      attr_reader :last_line

      # The heading's level, its number of #s; 0 for the items before a file's first heading.
      #: Integer
      attr_reader :level

      #: (heading: String?, items: Array[OutlineItem], first_line: Integer, last_line: Integer) -> void
      def initialize(heading:, items:, first_line:, last_line:)
        @heading = heading
        @level = heading.to_s[MARKS].to_s.length #: Integer
        @items = items
        @first_line = first_line
        @last_line = last_line
        freeze
      end

      # The section as the outline prints it: its heading, its items up to MOST_ITEMS, then how many more and the lines
      # from the first of them to the section's end, so the agent reads just those back.
      #: () -> Array[String]
      def lines
        left_out = @items.drop(MOST_ITEMS)
        first = left_out.first
        [*@heading, *@items.first(MOST_ITEMS).map(&:text),
         *("(#{left_out.length} more, lines #{first.line}-#{@last_line})" if first)]
      end

      # The section as a cut outline prints it: its heading, then, if it holds items, how many and the lines of the file
      # that hold them, so the agent reads just that section back.
      #: () -> Array[String]
      def cut_lines = [*@heading, *("(#{@items.length} more, lines #{@first_line}-#{@last_line})" if @items.any?)]

      #: () -> Integer
      def item_count = @items.length

      # Whether the outline prints fewer of its items than it holds, past MOST_ITEMS.
      #: () -> bool
      def leaves_items_out? = @items.length > MOST_ITEMS
    end
  end
end

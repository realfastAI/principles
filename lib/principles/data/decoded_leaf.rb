# typed: strict
# frozen_string_literal: true

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # One string in a captured request, split at reminder tags into segments and each segment into lines: reminder
    # inside a system-reminder tag, plain outside one.
    class DecodedLeaf
      OPENING = "<system-reminder>"
      CLOSING = "</system-reminder>"
      # Splits a string at each tag, keeping the tags as pieces of their own.
      TAGS = /(#{Regexp.escape(OPENING)}|#{Regexp.escape(CLOSING)})/
      # The segment each tag begins.
      SEGMENT_AFTER = { OPENING => "reminder", CLOSING => "plain" }.freeze #: Hash[String, String]

      #: (String) -> void
      def initialize(text)
        @text = text
        freeze
      end

      # Each of its lines holding one of patterns, with its segment and the byte offset in the string it starts at, as
      # [segment, line, offset]. Only the patterns it holds are looked for line by line, as a long string holds few of
      # many patterns.
      #: (Array[String]) -> Array[[String, String, Integer]]
      def holding(patterns)
        held = patterns.select { @text.include?(it) }
        held.empty? ? [] : lines.select { |_, line, _| held.any? { line.include?(it) } }
      end

      private

      # Each line with its segment and offset, in order.
      #: () -> Array[[String, String, Integer]]
      def lines
        segments.flat_map do |segment, part, at|
          part.split("\n", -1).map do |line|
            placed = [segment, line, at] #: [String, String, Integer]
            at += line.bytesize + 1
            placed
          end
        end
      end

      # Each segment with the byte offset its text starts at: plain until a reminder tag opens, reminder until one
      # closes, each tag's bytes counted between them.
      #: () -> Array[[String, String, Integer]]
      def segments
        segment = "plain"
        at = 0
        @text.split(TAGS, -1).filter_map do |piece|
          start = at
          at += piece.bytesize
          next [segment, piece, start] unless SEGMENT_AFTER.key?(piece)

          segment = SEGMENT_AFTER.fetch(piece)
          nil
        end
      end
    end
  end
end

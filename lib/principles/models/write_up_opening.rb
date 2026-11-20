# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The opening of a write-up's region in a file's text: what list-open-findings prints as a finding's
    # write_up_opening, and show-answer-check previews. This tool does not judge what it says.
    class WriteUpOpening
      # The longest opening printed whole; a longer one is cut and marked truncated.
      LIMIT = 200
      # A line that starts a new block, a list item or a heading, rather than continuing the paragraph before it.
      NEW_BLOCK = /\A(([-*+]|\d+[.)])\s|#)/
      # What a heading line starts with, a block of its own line.
      HEADING = "#"
      # The end of a sentence: its mark and any closing quotes or brackets, before a space or the end.
      SENTENCE_END = /[.!?]["')\]]*(?=\s|\z)/

      # One line of the file, as the opening reads it.
      class Line
        #: (String) -> void
        def initialize(text)
          @text = text
          freeze
        end

        # The line without its indentation or line break.
        #: () -> String
        def text = @text.strip

        #: () -> bool
        def blank? = text.empty?

        #: () -> bool
        def heading? = text.start_with?(HEADING)

        # Whether the line continues the paragraph before it: it is not blank and starts no new block. It keeps its
        # line break, which NEW_BLOCK's \s may match, so a bare "-" line still starts a list item.
        #: () -> bool
        def continues? = !blank? && !@text.lstrip.match?(NEW_BLOCK)
      end

      # lines are the file's lines; the region runs from index first up to, not including, index last.
      #: (lines: Array[String], first: Integer, last: Integer) -> void
      def initialize(lines:, first:, last:)
        @lines = lines.map { |each| Line.new(each) } #: Array[Line]
        @first = first
        @last = last
        freeze
      end

      # The opening from the region's first non-blank line, with that line's number. nil when every line in the
      # region is blank.
      #: () -> Hash[String, untyped]?
      def to_h
        index = (@first...@last).find { |each| !line(each).blank? } or return nil
        text = opening_text(index)
        { "text" => cut(text), "line" => index + 1 }.merge(text.length > LIMIT ? { "truncated" => true } : {})
      end

      private

      # text whole within the limit, or else up to the last whole word that fits, since a cut mid-word reads as a
      # different phrase; one word longer than the limit is cut where the limit falls.
      #: (String) -> String
      def cut(text)
        return text if text.length <= LIMIT

        fits = text[0, LIMIT + 1].to_s
        boundary = fits.rindex(" ") or return fits[0, LIMIT].to_s
        fits[0, boundary].to_s
      end

      # A heading line whole, since a heading is not a sentence and "F4." may number it. Otherwise the
      # first sentence: hard-wrapped lines joined with single spaces up to the sentence's end, or else to its
      # paragraph's end, a blank line, the next list item or heading, or the file's end. It runs past the region's
      # end, since a starting_at alone locates one line.
      #: (Integer) -> String
      def opening_text(index)
        return line(index).text if line(index).heading?

        sentence(paragraph_from(index).join(" "))
      end

      # The trimmed lines of the paragraph that starts at index, to its end in the file.
      #: (Integer) -> Array[String]
      def paragraph_from(index)
        rest = @lines.drop(index + 1).take_while(&:continues?)
        [line(index), *rest].map(&:text)
      end

      # text up to the end of its first sentence, or all of it when none ends. A mark inside a parenthesis, as in
      # "(e.g. this)", ends no sentence, since cutting there leaves a fragment.
      #: (String) -> String
      def sentence(text)
        ends = text.to_enum(:scan, SENTENCE_END).map { Regexp.last_match&.end(0) }
        found = ends.compact.find { |at| closed?(text[0, at].to_s) } or return text
        text[0, found].to_s
      end

      # Whether every parenthesis opened in text is closed by its end.
      #: (String) -> bool
      def closed?(text) = text.count("(") <= text.count(")")

      # The line at index, or a blank one past the file's end.
      #: (Integer) -> Line
      def line(index) = @lines[index] || Line.new("")
    end
  end
end

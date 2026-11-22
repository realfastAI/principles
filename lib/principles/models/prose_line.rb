# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One line of a file as prose reads it: blank, a heading, or continuing the paragraph or list item before it.
    class ProseLine
      # A line that starts a new block, a list item or a heading, rather than continuing the paragraph before it.
      NEW_BLOCK = /\A(([-*+]|\d+[.)])\s|#)/
      # What a heading line starts with, a block of its own line.
      HEADING = "#"

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
  end
end

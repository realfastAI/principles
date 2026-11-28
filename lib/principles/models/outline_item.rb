# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One item of a candidate file's outline, as printed, and the line of the file it starts on, so an outline that
    # leaves items out can say where to read them back.
    class OutlineItem
      #: String
      attr_reader :text

      # Counted from 1.
      #: Integer
      attr_reader :line

      #: (String, line: Integer) -> void
      def initialize(text, line:)
        @text = text
        @line = line
        freeze
      end
    end
  end
end

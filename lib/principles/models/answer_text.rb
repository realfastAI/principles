# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A value an agent gave where its answer asks for text, the one owner of whether it wrote any.
    class AnswerText
      #: (untyped) -> void
      def initialize(value)
        @value = value
        freeze
      end

      # Whether the agent wrote it: a string with more than whitespace in it.
      #: () -> bool
      def written? = @value.is_a?(String) && !@value.strip.empty? ? true : false

      # Whether the agent wrote it as one line: written, with no line break in it.
      #: () -> bool
      def one_line? = written? && !@value.include?("\n")

      # The text where field requires it: as written, or refused naming field.
      #: (String) -> String
      def required(field)
        unless written?
          raise Error.new("invalid_answer", "#{field} must be a nonempty string",
                          "Supply #{field} as the question asks.")
        end

        @value
      end
    end
  end
end

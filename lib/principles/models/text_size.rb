# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # How big a text that loads into context is: its bytes, and its tokens estimated as characters / 4, rounded up,
    # an estimate rather than a tokenizer count. A text not measured has no size, so nothing is printed for it.
    class TextSize
      #: (String?) -> void
      def initialize(text)
        @text = text
        freeze
      end

      # Its bytes, none for a text not measured.
      #: () -> Integer
      def bytes = @text.to_s.bytesize

      # Its tokens, estimated as characters / 4, rounded up; none for a text not measured.
      #: () -> Integer
      def estimated_tokens = (@text.to_s.length / 4.0).ceil

      # The size under fields' two names, its bytes then its tokens; empty when there is no text.
      #: ([String, String]) -> Hash[String, Integer]
      def under(fields)
        return {} unless @text

        bytes_field, tokens_field = fields
        { bytes_field => bytes, tokens_field => estimated_tokens }
      end
    end
  end
end

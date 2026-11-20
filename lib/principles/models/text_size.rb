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

      # The size under fields' two names, its bytes then its tokens; empty when there is no text.
      #: ([String, String]) -> Hash[String, Integer]
      def under(fields)
        text = @text or return {}

        bytes, tokens = fields
        { bytes => text.bytesize, tokens => (text.length / 4.0).ceil }
      end
    end
  end
end

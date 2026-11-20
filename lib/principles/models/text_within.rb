# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # A text cut to at most some characters, as a candidate file's outline prints its items, opening line and
    # description: whole when it fits, else back to a sentence end or a whole word.
    class TextWithin
      # Text up to its last sentence end that a space follows.
      SENTENCES = /\A.*[.!?](?=\s)/
      # Text up to its last whole word.
      WORDS = /\A.*(?=\s)/

      #: (String, at_most: Integer) -> void
      def initialize(text, at_most:)
        @text = text
        @at_most = at_most
        freeze
      end

      # Whether the text is longer than at_most characters.
      #: () -> bool
      def cut? = @text.length > @at_most

      # The text whole, else up to its last sentence end within at_most characters, else up to its last whole word.
      #: () -> String
      def kept
        return @text unless cut?

        sentences_kept || words_kept
      end

      # The text whole, else up to its last sentence end, else cut on a word ending in an ellipsis.
      #: () -> String
      def by_sentences = cut? && !sentences_kept ? "#{words_kept}…" : kept

      # The text whole, else cut on a word ending in an ellipsis.
      #: () -> String
      def by_words = cut? ? "#{words_kept}…" : @text

      private

      #: () -> String?
      def sentences_kept = window[SENTENCES]

      #: () -> String
      def words_kept = window[WORDS] || @text[0, @at_most].to_s

      # The text's first at_most characters and the one after, so a sentence or word ending at the cap is kept.
      #: () -> String
      def window = @text[0, @at_most + 1].to_s
    end
  end
end

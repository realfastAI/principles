# typed: strict
# frozen_string_literal: true

require "json"
require_relative "parser_message"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # JSON text that an agent or a person wrote, parsed so that an object naming one key twice is refused on
    # every json version. Ruby 3.4's own json keeps the last of two duplicates without a word, so a reviewer
    # reading a diff could see one value while this tool used the other.
    class JsonText
      # An object under construction, which refuses a key it already holds.
      class UniqueKeys
        #: () -> void
        def initialize
          @pairs = {} #: Hash[untyped, untyped]
        end

        #: (untyped, untyped) -> untyped
        def []=(key, value)
          raise JSON::ParserError, "duplicate key #{key.inspect}" if @pairs.key?(key)

          @pairs[key] = value
        end

        #: () -> Hash[untyped, untyped]
        def to_h
          @pairs
        end
      end

      #: (String) -> void
      def initialize(text)
        @text = text
        freeze
      end

      # The parsed value, made only of plain hashes and arrays; raises JSON::ParserError on a duplicate key, and on
      # text it cannot parse with the parser's message, the rest of the input it quotes cut to an excerpt.
      #: () -> untyped
      def parsed
        plain(JSON.parse(@text, object_class: UniqueKeys))
      rescue JSON::ParserError => e
        raise JSON::ParserError, ParserMessage.new(@text, e.message).to_s
      end

      private

      #: (untyped) -> untyped
      def plain(value)
        case value
        when UniqueKeys then value.to_h.transform_values { |each| plain(each) }
        when Array then value.map { |each| plain(each) }
        else value
        end
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "digest"
require "json"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The digest of what a JSON value says: its objects' keys in sorted order at every depth and its lists in their
    # own, so a formatter or a hand edit that only reorders a file's keys leaves it unchanged. A map's
    # version and an audit record's revision are each one.
    class JsonDigest
      #: (untyped) -> void
      def initialize(value)
        @text = JSON.generate(in_key_order(value)) #: String
        freeze
      end

      #: () -> String
      def to_s = Digest::SHA256.hexdigest(@text)

      private

      #: (untyped) -> untyped
      def in_key_order(value)
        case value
        when Hash then value.sort.to_h { |key, inner| [key, in_key_order(inner)] }
        when Array then value.map { |inner| in_key_order(inner) }
        else value
        end
      end
    end
  end
end

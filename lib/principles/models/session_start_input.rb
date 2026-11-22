# typed: strict
# frozen_string_literal: true

require "json"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The JSON a SessionStart hook is given on stdin, as far as report-at-session-start reads it: the source the
    # session started from. Input that is not JSON, or names no source a host sends, reads as a startup, since a
    # hook reports what it can rather than refuse.
    class SessionStartInput
      # The sources a SessionStart hook names.
      SOURCES = %w[startup resume clear compact].freeze #: Array[String]

      # The source the session started from: startup, resume, clear or compact.
      #: String
      attr_reader :source

      #: (String) -> void
      def initialize(text)
        given = parsed(text)
        given = given["source"] if given.is_a?(Hash)
        @source = SOURCES.include?(given) ? given.to_s : "startup" #: String
        freeze
      end

      private

      #: (String) -> untyped
      def parsed(text)
        JSON.parse(text)
      rescue JSON::ParserError
        nil
      end
    end
  end
end

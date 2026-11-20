# typed: strict
# frozen_string_literal: true

require_relative "line_span"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The text a locator found now: its file, the lines it spans and the hash of what it says. A Locator says where
    # to look; this is what was found there, as Project#locate finds it.
    class LocatedText
      # The text found, from what Project#locate gives.
      #: (Hash[String, untyped]) -> LocatedText
      def self.of(found)
        new(path: found.fetch("path"), first_line: found.fetch("first_line"), last_line: found.fetch("last_line"),
            sha256: found.fetch("sha256"))
      end

      #: String
      attr_reader :path, :sha256

      #: Integer
      attr_reader :first_line, :last_line

      #: (path: String, first_line: Integer, last_line: Integer, sha256: String) -> void
      def initialize(path:, first_line:, last_line:, sha256:)
        @path = path
        @first_line = first_line
        @last_line = last_line
        @sha256 = sha256
        freeze
      end

      # The lines it spans, whole_file when it is its whole file.
      #: (?whole_file: bool) -> LineSpan
      def span(whole_file: false) = LineSpan.new(@first_line, @last_line, whole_file:)

      # Its first and last lines, as a request prints them.
      #: () -> Hash[String, Integer]
      def lines = { "first_line" => @first_line, "last_line" => @last_line }
    end
  end
end

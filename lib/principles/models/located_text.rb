# typed: strict
# frozen_string_literal: true

require "digest"
require_relative "line_span"
require_relative "locator"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The text a locator found now: its file, the lines it spans and the hash of what it says. A Locator says where
    # to look; this is what was found there, as MemberFile#locate finds it.
    class LocatedText
      #: String
      attr_reader :path, :sha256

      #: Integer
      attr_reader :first_line, :last_line

      # path is the file's spelling as git tracks it, which may differ from the locator's in case; text is what
      # was found, whose hash and length it keeps, so the two never disagree.
      #: (locator: Locator, path: String, first_line: Integer, last_line: Integer, text: String) -> void
      def initialize(locator:, path:, first_line:, last_line:, text:)
        @locator = locator
        @path = path
        @first_line = first_line
        @last_line = last_line
        @sha256 = Digest::SHA256.hexdigest(text) #: String
        @characters = text.length #: Integer
        freeze
      end

      # The lines it spans, whole_file when it is its whole file.
      #: (?whole_file: bool) -> LineSpan
      def span(whole_file: false) = LineSpan.new(@first_line, @last_line, whole_file:)

      # Its first and last lines, as a request prints them.
      #: () -> Hash[String, Integer]
      def lines = { "first_line" => @first_line, "last_line" => @last_line }

      # Where it was found and the hash of what it says, as show-principle prints a member's snapshot. query appears
      # only for a locator that has one, so every other member's snapshot, and each request id digesting it, is
      # unchanged.
      #: () -> Hash[String, untyped]
      def to_h
        { "path" => @path, "heading" => @locator.heading, "starting_at" => @locator.starting_at,
          "sha256" => @sha256, "characters" => @characters, **lines }.merge(@locator.to_h.slice("query"))
      end
    end
  end
end

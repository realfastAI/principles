# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One instruction a judgement request prints under its own field: its paragraphs, each printed only when the
    # request holds the case it explains, and every one when the agent reads the field whole.
    class Instruction
      #: String
      attr_reader :field

      # An instruction of a prompt's paragraphs, each held when the block, given the paragraph, says the request
      # holds its case; key a case by what the paragraph says, never by its position, which an edit moves.
      #: (String, String) { (String) -> bool } -> Instruction
      def self.of_paragraphs(field, text, &held)
        new(field, text.split("\n\n").map { |paragraph| [paragraph, held.call(paragraph)] })
      end

      # paragraphs are each paragraph, in order, with whether the request holds its case.
      #: (String, Array[[String, bool]]) -> void
      def initialize(field, paragraphs)
        @field = field
        @paragraphs = paragraphs
        freeze
      end

      # The field as the request prints it, with the paragraphs whose case it holds; nothing when it holds none.
      #: () -> Hash[String, String]
      def printed
        held = @paragraphs.select { |_, case_held| case_held }.map(&:first)
        held.empty? ? {} : { @field => held.join("\n\n") }
      end

      # Every paragraph, whether or not the request holds its case.
      #: () -> String
      def whole = @paragraphs.map(&:first).join("\n\n")

      # Whether the request prints some paragraphs and leaves others out, so the field read as printed is not whole.
      #: () -> bool
      def trimmed? = @paragraphs.any? { |_, held| held } && @paragraphs.any? { |_, held| !held }
    end

    # The guide to an answer's shapes a judgement request prints under its own field: its entries, each printed only
    # when the request holds the case it shows, and every one when the agent reads the field whole.
    class GuideInstruction
      #: String
      attr_reader :field

      # guide is every entry; held says, by entry name, whether the request holds its case. narrowed is, by name, an
      # entry as the request prints it when it holds the entry's case but not every case within it.
      #: (String, Hash[String, untyped], ?narrowed: Hash[String, untyped]) { (String) -> bool } -> void
      def initialize(field, guide, narrowed: {}, &held)
        @field = field
        @guide = guide
        @held = guide.filter_map { |name, entry| [name, narrowed.fetch(name, entry)] if held.call(name) }
                     .to_h #: Hash[String, untyped]
        freeze
      end

      # The field as the request prints it, with the entries whose case it holds; nothing when it holds none.
      #: () -> Hash[String, untyped]
      def printed = @held.empty? ? {} : { @field => @held }

      # Every entry, whether or not the request holds its case.
      #: () -> Hash[String, untyped]
      def whole = @guide

      # Whether the request prints some entries and leaves others out, so the field read as printed is not whole.
      #: () -> bool
      def trimmed? = !@held.empty? && @held != @guide
    end
  end
end

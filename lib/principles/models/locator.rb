# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Where some text is in the project: a path, with a heading, a passage between starting_at and ending_at, or a
    # frontmatter query inside it, or none of those to name the whole file. A member's reference, an evidence item
    # and a write-up pointer each name text this way. It keeps the hash it was given, keys and order, since request
    # ids and record bytes digest it.
    class Locator
      # What narrows a locator within its path, as references and the answer schemas name them; a locator naming
      # none of them names its whole file. A member map calls the heading "section", which Member#reference
      # translates.
      KEYS = %w[heading starting_at ending_at query].freeze #: Array[String]

      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields.dup.freeze #: Hash[String, untyped]
        freeze
      end

      # The file it points into.
      #: () -> String
      def path = @fields.fetch("path")

      # The heading of the section it names, if it names one.
      #: () -> String?
      def heading = @fields["heading"]

      # The opening text of the passage it names, if it names one.
      #: () -> String?
      def starting_at = @fields["starting_at"]

      # The closing text of the passage it names, if it gives one.
      #: () -> String?
      def ending_at = @fields["ending_at"]

      # The frontmatter field it names, as a JSONPath query, if it names one.
      #: () -> String?
      def query = @fields["query"]

      # Whether it names its whole file, with no heading, passage or query inside it.
      #: () -> bool
      def whole_file? = KEYS.none? { |key| @fields.key?(key) }

      # A heading's full section, with no narrower passage or frontmatter query.
      #: () -> bool
      def complete_section?
        !heading.nil? && starting_at.nil? && ending_at.nil? && query.nil?
      end

      # This locator with its passage's opening quoted without its leading whitespace; nil when the opening has none.
      #: () -> Locator?
      def with_opening_unindented
        opening = starting_at or return nil
        unindented = opening.lstrip
        Locator.new(@fields.merge("starting_at" => unindented)) unless unindented == opening
      end

      # The locator as it was given.
      #: () -> Hash[String, untyped]
      def to_h = @fields
    end
  end
end

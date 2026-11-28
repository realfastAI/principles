# typed: strict
# frozen_string_literal: true

require_relative "outline_section"
require_relative "without_prose"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A script's or configuration file's text as its outline reads it: its whole-line `#` comments, where a hook or a
    # CI check writes the rule it enforces, which a survey reading Markdown headings alone never found.
    class ScriptComments
      include WithoutProse

      # A whole-line comment and its text, past any indent and the space after the mark.
      COMMENT = /\A\s*#\s?(.*)/
      # A first line naming the script's interpreter, which is no comment.
      SHEBANG = /\A#!/
      # A Ruby magic comment, such as frozen_string_literal or Sorbet's typed sigil, which sets how the file runs and
      # states no rule.
      MAGIC = /\A#\s*(?:frozen_string_literal|typed|encoding|coding|warn_indent|shareable_constant_value):/

      #: (String) -> void
      def initialize(text)
        @lines = text.lines.map(&:chomp) #: Array[String]
        freeze
      end

      # One section with no heading, its items the comments, spanning the lines from the first to the last; none when
      # the text has no comment.
      #: () -> Array[OutlineSection]
      def sections
        comments = comment_numbers
        first = comments.first or return []

        items = comments.map { |number| OutlineItem.new(item(@lines.fetch(number - 1)), line: number) }
        [OutlineSection.new(heading: nil, items:, first_line: first, last_line: comments.fetch(-1))]
      end

      private

      # The number in the file, counted from 1, of each line that is a comment with text.
      #: () -> Array[Integer]
      def comment_numbers
        @lines.each_index.filter_map do |index|
          line = @lines.fetch(index)
          next if (index.zero? && line.match?(SHEBANG)) || line.match?(MAGIC)

          index + 1 unless line[COMMENT, 1].to_s.strip.empty?
        end
      end

      # A comment as its mark and its whole text, so any line can be quoted as an exact --starting-at.
      #: (String) -> String
      def item(line) = "# #{line[COMMENT, 1].to_s.strip}"
    end
  end
end

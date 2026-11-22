# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "locator"
require_relative "member_region"
require_relative "line_span"
require_relative "located_text"
require_relative "write_up_opening"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The text of one project file, as the type that knows how to find a member in it. It holds text, not a
    # file, so the same rules apply to a file on disk and to the file at a commit. Each type finds the region
    # a member names; passage anchors then narrow it the same way in every type.
    class MemberFile
      # The refusals, raised here and by the file types, that say a member's reference finds nothing in a file's
      # text, rather than that the reference itself is wrong. Add a new one here when it raises one.
      PLACEMENT_REFUSALS = %w[section_not_found ambiguous_heading passage_not_found ambiguous_passage
                              passage_end_not_found section_needs_markdown query_needs_frontmatter field_not_found
                              unsupported_frontmatter duplicate_frontmatter_key].freeze
      # The placement refusals of a quote the text does not hold, which a pointer that is not a member may also
      # repair by pointing at other text.
      QUOTE_NOT_FOUND = %w[passage_not_found passage_end_not_found].freeze #: Array[String]
      # The placement refusals that mean a member's place in its file is gone: its heading, passage anchor or
      # frontmatter field no longer matches, so it is lost there, not changed and not unreadable.
      PLACE_LOST = %w[section_not_found passage_not_found passage_end_not_found ambiguous_heading
                      ambiguous_passage field_not_found].freeze #: Array[String]

      # The file name endings read as Markdown, where a # line is a heading and not a comment.
      MARKDOWN = /\.(md|markdown|mdx)\z/i #: Regexp

      # The file type for path, chosen by its name.
      #: (path: String, text: String) -> MemberFile
      def self.for(path:, text:)
        (path.match?(MARKDOWN) ? MarkdownFile : PlainTextFile).new(path: path, text: text)
      end

      #: String
      attr_reader :path
      #: String
      attr_reader :text

      #: (path: String, text: String) -> void
      def initialize(path:, text:)
        @path = path
        @text = text
        freeze
      end

      # Where the member locator names is in this text, and the hash of what it says there.
      #: (Locator) -> LocatedText
      def locate(locator)
        refuse_mixed_locators(locator)
        lines = @text.lines
        first, last = region(lines, locator)
        selected = lines[first...last].to_a.join
        start_text = locator.starting_at
        if start_text
          selected_region = MemberRegion.new(self, span: LineSpan.new(first + 1, last))
          first, last, selected = selected_region.passage(start_text, locator.ending_at)
        end
        snapshot(locator, selected, first + 1, last)
      end

      # Only a newly supplied add/move location needs an unambiguous ending; existing references keep lookup.
      #: (Locator) -> LocatedText
      def locate_for_authoring(locator)
        found = locate(locator)
        opening = locator.starting_at
        ending = locator.ending_at
        if opening && ending
          first, last = region(@text.lines, locator)
          selected_region = MemberRegion.new(self, span: LineSpan.new(first + 1, last))
          selected_region.check_authored_ending(opening, ending)
        end
        found
      end

      # The last line of the paragraph or list item that a passage named by its opening alone maps only the first
      # line of; nil here, since only Markdown has such blocks, which MarkdownFile finds.
      #: (Locator) -> Integer?
      def continues_to(_locator) = nil

      # The lines of the region locator names, as the agent reads them.
      #: (Locator) -> Array[String]
      def lines_of(locator)
        located = locate(locator)
        @text.lines[(located.first_line - 1)...located.last_line].to_a
      end

      # The opening of the region locator names, after the heading line itself when it names a heading, as
      # WriteUpOpening finds it; nil when there is none. This tool does not judge what it says.
      #: (Locator) -> Hash[String, untyped]?
      def write_up_opening(locator)
        located = locate(locator)
        heading_line = locator.heading && !locator.starting_at ? 1 : 0
        WriteUpOpening.new(lines: @text.lines, first: located.first_line - 1 + heading_line,
                           last: located.last_line).to_h
      end

      private

      # What locate found: the member's place, the hash of its text and its span.
      #: (Locator, String, Integer, Integer) -> LocatedText
      def snapshot(locator, selected, first_line, last_line)
        LocatedText.new(locator:, path: @path, first_line:, last_line:, text: selected)
      end

      # A query names a field whole, so it takes no section or passage beside it.
      #: (Locator) -> void
      def refuse_mixed_locators(locator)
        return unless locator.query && (locator.heading || locator.starting_at)

        raise Error.new("query_with_other_locators",
                        "--query names a whole field, so it takes no --section or --starting-at",
                        "Give --query alone, or --section and --starting-at without it.", @path)
      end

      # The line range a member names before any passage narrows it; each file type says.
      #: (Array[String], Locator) -> [Integer, Integer]
      def region(lines, locator)
        raise NotImplementedError, "#{self.class} names no region"
      end
    end
  end
end

require_relative "markdown_file"
require_relative "plain_text_file"

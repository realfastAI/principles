# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "frontmatter_fields"
require_relative "outline_section"
require_relative "text_within"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A Markdown file's text as its outline reads it: its sections, each a heading and the top-level list items under
    # it, its frontmatter description and its opening line. One user scripted a heading grep over 45 files to survey
    # them, and missed a principles section written as one numbered list, so the outline reads both.
    class MarkdownText
      HEADING = /\A#+\s/
      FENCE = /\A\s*(?:```|~~~)/
      # A top-level list item, its marker and its text; an indented one is nested, and left out.
      ITEM = /\A(\d+\.|[-*])\s+(.*)/
      # A horizontal rule, such as `* * *` or `- - -`, which is no item.
      RULE = /\A([-*_])(?:\s*\1){2,}\s*\z/
      LINK = /\[([^\]]*)\]\([^)]*\)/
      BOLD_LEAD = /\A\*\*[^*]+\*\*/
      # The most characters of the opening line printed, cut back to a sentence end, or else to a whole word. A cut
      # mid-clause left 30 of one user's 45 opening lines a fragment. The line is short only when
      # its first sentence is and the next runs past the cap, or an abbreviation such as "e.g." ends it early; that is
      # accepted, since the file's path and outline still say what it holds.
      OPENING_CHARACTERS = 160
      # The most characters of a description a cut keeps, cut back to a sentence end, or else to a whole word. The
      # one user's descriptions printed 12,537 B uncut, and suggested about 300.
      DESCRIPTION_CHARACTERS = 300

      # A description's key and any block scalar indicator, which its text starts after.
      DESCRIPTION_KEY = /\Adescription:\s*(?:[>|][-+]?\s)?/
      # A value inside a matching pair of quotes, printed without them; its escapes are left as written.
      QUOTED = /\A(["'])(.*)\1\z/

      #: (String) -> void
      def initialize(text)
        @lines = text.lines #: Array[String]
        @frontmatter = FrontmatterFields.new(path: "", lines: @lines) #: FrontmatterFields
        freeze
      end

      # Each heading with the items under it, and the items before the first heading when there are any, each with
      # the lines of the file it spans.
      #: () -> Array[OutlineSection]
      def sections
        body = unfenced
        starts = [0, *body.each_index.select { |index| body.fetch(index).match?(HEADING) }].uniq
        starts.zip(starts.drop(1)).filter_map do |first, after|
          section(body[first...(after || body.length)] || [], first_line: body_start + first + 1)
        end
      end

      # The frontmatter's description as one line of text; nil without one, or where this tool refuses to read it.
      #: () -> String?
      def description
        written = @frontmatter.field_lines("$.description") or return nil
        text = written.map(&:strip).join(" ").sub(DESCRIPTION_KEY, "").strip
        text[QUOTED, 2] || text
      rescue Error
        nil
      end

      # The description, past DESCRIPTION_CHARACTERS cut to its last sentence end within them, saying how many more
      # characters it holds and the lines of the file that hold it, so the agent reads just those back.
      #: () -> String?
      def cut_description
        text = description or return nil
        within = TextWithin.new(text, at_most: DESCRIPTION_CHARACTERS)
        return text unless within.cut?

        kept = within.kept
        first, last = @frontmatter.field("$.description")
        "#{kept} (#{text.length - kept.length} more characters, lines #{first + 1}-#{last})"
      end

      # The first prose paragraph of the body, outside headings, lists, tables and code, its hard-wrapped lines
      # joined, with links as their text. The first physical line was a fragment in a hard-wrapped file.
      #: () -> String?
      def opening_line
        body = unfenced
        first = body.index { |line| prose?(line) } or return nil
        paragraph = body.drop(first).take_while { |line| prose?(line) }.map(&:strip).join(" ")
        TextWithin.new(paragraph.gsub(LINK, '\1'), at_most: OPENING_CHARACTERS).by_sentences
      end

      private

      # The section these body lines hold, the first of them at first_line in the file; nil when they hold neither a
      # heading nor an item.
      #: (Array[String], first_line: Integer) -> OutlineSection?
      def section(lines, first_line:)
        heading = lines.first if lines.first&.match?(HEADING)
        items = outline_items(lines, first_line:)
        return nil unless heading || items.any?

        OutlineSection.new(heading:, items:, first_line:, last_line: first_line + lines.length - 1)
      end

      # The top-level list items among these body lines, each on its line of the file, the first of them first_line.
      #: (Array[String], first_line: Integer) -> Array[OutlineItem]
      def outline_items(lines, first_line:)
        lines.each_index.select { |index| item?(lines.fetch(index)) }
             .map { |index| OutlineItem.new(item(lines.fetch(index)), line: first_line + index) }
      end

      # A top-level list item, not a horizontal rule written with the same marks.
      #: (String) -> bool
      def item?(line) = line.match?(ITEM) && !line.match?(RULE)

      # The index in the file of the body's first line, after any frontmatter.
      #: () -> Integer
      def body_start = (@frontmatter.closing_line || -1) + 1

      #: (String) -> bool
      def prose?(line)
        text = line.strip
        !text.empty? && !text.match?(HEADING) && !text.match?(ITEM) && !text.match?(RULE) && !text.start_with?("|")
      end

      # The body's lines, after any frontmatter, each line of a code fence blank, so a fence ends a paragraph.
      #: () -> Array[String]
      def unfenced
        fenced = false #: bool
        body = @lines.drop(body_start).map(&:chomp)
        body.map do |line|
          fenced = !fenced if line.match?(FENCE)
          fenced || line.match?(FENCE) ? "" : line
        end
      end

      # An item by its marker and its bold lead, or its opening words, with links as their text.
      #: (String) -> String
      def item(line)
        marker, text = line.match(ITEM)&.captures
        text = text.to_s.gsub(LINK, '\1')
        "#{marker} #{text[BOLD_LEAD] || TextWithin.new(text, at_most: OutlineSection::ITEM_CHARACTERS).by_words}"
      end
    end
  end
end

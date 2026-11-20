# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "frontmatter_fields"
require_relative "outline_group"
require_relative "outline_section"
require_relative "text_within"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # One candidate file's outline, as the survey reads it in place of the file: its Markdown headings in order, and
    # under each its top-level list items. One user scripted a heading grep over 45 files to survey them,
    # and missed a principles section written as one numbered list, so this tool prints both.
    class CandidateOutline
      HEADING = /\A#+\s/
      FENCE = /\A\s*(?:```|~~~)/
      # A top-level list item, its marker and its text; an indented one is nested, and left out.
      ITEM = /\A(\d+\.|[-*])\s+(.*)/
      # A horizontal rule, such as `* * *` or `- - -`, which is no item.
      RULE = /\A([-*_])(?:\s*\1){2,}\s*\z/
      LINK = /\[([^\]]*)\]\([^)]*\)/
      BOLD_LEAD = /\A\*\*[^*]+\*\*/
      # The most characters of an item printed, cut back to a whole word.
      ITEM_CHARACTERS = 60
      # The most characters of the opening line printed, cut back to a sentence end, or else to a whole word. A cut
      # mid-clause left 30 of one user's 45 opening lines a fragment. The line is short only when
      # its first sentence is and the next runs past the cap, or an abbreviation such as "e.g." ends it early; that is
      # accepted, since the file's path and outline still say what it holds.
      OPENING_CHARACTERS = 160
      # The cuts that shorten an outline to fit a budget, in the order they are made, each keeping those before it.
      # The last leaves the whole outline out, which a big enough project needs once every other cut is made.
      CUTS = %w[description items headings opening_line outline].freeze
      # The cuts made on a root entry file, every one but the last, since a host loads it in every session.
      ENTRY_FILE_CUTS = CUTS.length - 1 #: Integer
      # The deepest heading level a cut outline keeps once its headings are folded.
      FOLDED_BELOW = 2
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

      # The outline as the survey reads it: the whole frontmatter description and the opening line, each when the file
      # has one, and the lines, with the first `cuts` of CUTS made.
      #: (?cuts: Integer) -> Hash[String, untyped]
      def to_h(cuts: 0)
        return {} if left_out?(cuts)

        { "description" => made?("description", cuts) ? cut_description : description,
          "opening_line" => (opening_line unless made?("opening_line", cuts) && description),
          "outline" => outline_lines(cuts) }.compact
      end

      # Whether the first `cuts` of CUTS cut the outline's lines, rather than only its description.
      #: (Integer) -> bool
      def outline_cut?(cuts) = made?("items", cuts)

      # Whether the first `cuts` of CUTS leave the whole outline out, the file printing its path and size alone.
      #: (Integer) -> bool
      def left_out?(cuts) = made?("outline", cuts)

      # Each line of the outline, as Markdown, leaving out what a code fence holds.
      #: () -> Array[String]
      def lines = sections.flat_map(&:lines)

      # The outline with its list items cut, each heading that held some followed by how many.
      #: () -> Array[String]
      def cut_lines = sections.flat_map(&:cut_lines)

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

      private

      # The outline's lines with the first `cuts` of CUTS made: whole, with items cut, or with third-level and deeper
      # headings folded into the heading above, whose 11,112 B kept one user's result over budget.
      #: (Integer) -> Array[String]
      def outline_lines(cuts)
        return lines unless outline_cut?(cuts)
        return cut_lines unless made?("headings", cuts)

        groups.flat_map(&:folded_lines)
      end

      # Each section at FOLDED_BELOW or above, with the deeper sections after it; a file's first sections stand as a
      # group of their own whatever their level.
      #: () -> Array[OutlineGroup]
      def groups
        sections.slice_before { |section| section.level <= FOLDED_BELOW }
                .map { |(section, *deeper)| OutlineGroup.new(section, deeper) }
      end

      # Whether the first `cuts` of CUTS include the one named.
      #: (String, Integer) -> bool
      def made?(cut, cuts) = CUTS.take(cuts).include?(cut)

      # The section these body lines hold, the first of them at first_line in the file; nil when they hold neither a
      # heading nor an item.
      #: (Array[String], first_line: Integer) -> OutlineSection?
      def section(lines, first_line:)
        heading = lines.first if lines.first&.match?(HEADING)
        items = lines.select { |line| item?(line) }.map { |line| item(line) }
        return nil unless heading || items.any?

        OutlineSection.new(heading:, items:, first_line:, last_line: first_line + lines.length - 1)
      end

      # A top-level list item, not a horizontal rule written with the same marks.
      #: (String) -> bool
      def item?(line) = line.match?(ITEM) && !line.match?(RULE)

      # The index in the file of the body's first line, after any frontmatter.
      #: () -> Integer
      def body_start = (@frontmatter.closing_line || -1) + 1

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
        "#{marker} #{text[BOLD_LEAD] || TextWithin.new(text, at_most: ITEM_CHARACTERS).by_words}"
      end
    end
  end
end

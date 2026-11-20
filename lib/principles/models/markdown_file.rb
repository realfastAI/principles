# typed: strict
# frozen_string_literal: true

require_relative "member_file"
require_relative "frontmatter_fields"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # A Markdown file, where a member may be a section: a heading and what follows it, up to the next heading
    # at its level or above.
    class MarkdownFile < MemberFile
      private

      # The frontmatter field the reference's query names, or the section under its heading, or the whole text.
      #: (Array[String], Locator) -> [Integer, Integer]
      def region(lines, locator)
        query = locator.query
        return FrontmatterFields.new(path: @path, lines: lines).field(query) if query

        section(lines, locator.heading)
      end

      # The line range of the Markdown section under heading, or the whole text without one. A section runs
      # to the next heading at its level or above, so its subsections come with it.
      #: (Array[String], String?) -> [Integer, Integer]
      def section(lines, heading)
        return [0, lines.length] unless heading

        headings = heading_lines(lines)
        first = only_heading(lines, headings, heading)
        level = lines.fetch(first)[/\A\#+/].to_s.length
        [first, headings.find { |i| i > first && lines.fetch(i).match?(/\A\#{1,#{level}}\s/) } || lines.length]
      end

      # The indexes of lines that are Markdown headings: a # line outside the leading frontmatter and outside
      # fenced code, where # starts a comment.
      #: (Array[String]) -> Array[Integer]
      def heading_lines(lines)
        fence = nil #: String?
        (frontmatter_end(lines)...lines.length).select do |i|
          marker = lines.fetch(i)[/\A {0,3}(`{3,}|~{3,})/, 1]
          fence = fenced_after(fence, marker) if marker
          !marker && fence.nil? && lines.fetch(i).match?(/\A\#{1,6}\s/)
        end
      end

      # The fence still open after a line that starts with marker: it opens one, or closes the one open
      # when it repeats that fence's character at least as many times.
      #: (String?, String) -> String?
      def fenced_after(fence, marker)
        return marker unless fence

        marker.start_with?(fence) ? nil : fence
      end

      # The index of the first line after the frontmatter, which runs from a first line of --- to the next.
      #: (Array[String]) -> Integer
      def frontmatter_end(lines)
        return 0 unless lines.first&.chomp == "---"

        closing = (1...lines.length).find { |i| lines.fetch(i).chomp == "---" }
        closing ? closing + 1 : 0
      end

      # Whether line is a heading of one to six #s, then whitespace, whose text is heading. It compares strings
      # rather than building a pattern from heading, so a heading from a map cannot make the match slow.
      #: (String, String) -> bool
      def titled?(line, heading)
        marks = line[/\A#+/].to_s.length
        return false unless (1..6).cover?(marks)

        rest = line[marks..].to_s
        rest.match?(/\A\s/) && rest.strip == heading
      end

      #: (Array[String], Array[Integer], String) -> Integer
      def only_heading(lines, headings, heading)
        matches = headings.select { |i| titled?(lines.fetch(i), heading) }
        return matches.fetch(0) if matches.length == 1
        if matches.empty?
          raise Error.new("section_not_found", "No Markdown heading #{heading.inspect}",
                          "Give the heading's exact text without its # marks, " \
                          "or leave out the heading to point at the whole file.", @path)
        end

        raise Error.new("ambiguous_heading", "Heading #{heading.inspect} has #{matches.length} matches",
                        "Use a unique Markdown heading, or leave out the heading to point at the whole file.", @path)
      end
    end
  end
end

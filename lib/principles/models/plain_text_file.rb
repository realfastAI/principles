# typed: strict
# frozen_string_literal: true

require_relative "member_file"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # A file that is not Markdown, such as a script or a config file. It has no sections, so a member is the
    # whole file or a passage of it, and a # line is never read as a heading.
    class PlainTextFile < MemberFile
      private

      # The whole text; a heading is refused, since a # line here is a comment, not a heading.
      #: (Array[String], Locator) -> [Integer, Integer]
      def region(lines, locator)
        if locator.heading
          raise Error.new("section_needs_markdown", "#{@path} is not Markdown, so it has no sections",
                          "Name the member by a passage with --starting-at TEXT [--ending-at TEXT], or map the " \
                          "whole file.", @path)
        end

        if locator.query
          raise Error.new("query_needs_frontmatter", "#{@path} is not Markdown, so it has no frontmatter to query",
                          "Name the member by a passage with --starting-at TEXT, or map the whole file.", @path)
        end

        [0, lines.length]
      end
    end
  end
end

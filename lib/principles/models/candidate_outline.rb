# typed: strict
# frozen_string_literal: true

require_relative "markdown_text"
require_relative "outline_group"
require_relative "script_comments"
require_relative "workflow_jobs"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One candidate file's outline, as the survey reads it in place of the file: the sections of the text it outlines,
    # and that text's description and opening line when it has them, cut to fit a budget.
    class CandidateOutline
      # The cuts that shorten an outline to fit a budget, in the order they are made, each keeping those before it.
      # The last leaves the whole outline out, which a big enough project needs once every other cut is made.
      CUTS = %w[description items headings opening_line outline].freeze
      # The cuts made on a root entry file, every one but the last, since a host loads it in every session.
      ENTRY_FILE_CUTS = CUTS.length - 1 #: Integer
      # The deepest heading level a cut outline keeps once its headings are folded.
      FOLDED_BELOW = 2

      # The file's text, read as the kind of text `as` names.
      #: (String, ?as: singleton(MarkdownText) | singleton(ScriptComments) | singleton(WorkflowJobs)) -> void
      def initialize(text, as: MarkdownText)
        @text = as.new(text) #: MarkdownText | ScriptComments | WorkflowJobs
        freeze
      end

      # The outline as the survey reads it: the whole frontmatter description and the opening line, each when the file
      # has one, and the lines, with the first `cuts` of CUTS made.
      #: (?cuts: Integer) -> Hash[String, untyped]
      def to_h(cuts: 0)
        return {} if left_out?(cuts)

        description = @text.description
        { "description" => made?("description", cuts) ? @text.cut_description : description,
          "opening_line" => (@text.opening_line unless made?("opening_line", cuts) && description),
          "outline" => outline_lines(cuts) }.compact
      end

      # Whether the outline's lines are cut once the first `cuts` of CUTS are made: by those cuts, rather than only its
      # description, or by a section leaving items out past OutlineSection::MOST_ITEMS before any cut.
      #: (Integer) -> bool
      def outline_cut?(cuts) = made?("items", cuts) || sections.any?(&:leaves_items_out?)

      # Whether the first `cuts` of CUTS leave the whole outline out, the file printing its path and size alone.
      #: (Integer) -> bool
      def left_out?(cuts) = made?("outline", cuts)

      # Each line of the outline, as Markdown, leaving out what a code fence holds.
      #: () -> Array[String]
      def lines = sections.flat_map(&:lines)

      # The outline with its list items cut, each heading that held some followed by how many.
      #: () -> Array[String]
      def cut_lines = sections.flat_map(&:cut_lines)

      # The text's sections, each a heading with the items under it and the lines of the file it spans.
      #: () -> Array[OutlineSection]
      def sections = @text.sections

      private

      # The outline's lines with the first `cuts` of CUTS made: whole, with items cut, or with third-level and deeper
      # headings folded into the heading above, whose 11,112 B kept one user's result over budget.
      #: (Integer) -> Array[String]
      def outline_lines(cuts)
        return lines unless made?("items", cuts)
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
    end
  end
end

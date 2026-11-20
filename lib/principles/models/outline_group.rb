# typed: strict
# frozen_string_literal: true

require_relative "outline_section"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # One section of a candidate file's outline and the deeper sections under it, which a cut outline folds into it
    # once its headings are cut too.
    class OutlineGroup
      #: (OutlineSection, Array[OutlineSection]) -> void
      def initialize(section, deeper)
        @section = section
        @deeper = deeper
        freeze
      end

      # The group as a cut outline prints it once its deeper headings are folded: the section's heading, then how many
      # items it and they hold under how many headings, and the lines they span.
      #: () -> Array[String]
      def folded_lines
        last = @deeper.last or return @section.cut_lines

        items = @section.item_count + @deeper.sum(&:item_count)
        headings = "#{@deeper.length} heading#{"s" unless @deeper.one?}"
        [*@section.heading, "(#{items} more under #{headings}, lines #{@section.first_line}-#{last.last_line})"]
      end
    end
  end
end

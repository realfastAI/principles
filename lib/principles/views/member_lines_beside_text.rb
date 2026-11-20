# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A member's lines at its last full audit and now, as AcknowledgedSinceLastAudit prints them, beside the member's
    # text printed whole, as its start-audit --part prints it: each side now names where it starts in the text and
    # how many of its lines it spans, so the part carries each line now once.
    class MemberLinesBesideText
      #: (Hash[String, untyped]) -> void
      def initialize(member_lines)
        @member_lines = member_lines
        freeze
      end

      # The lines as printed, each side now that lists its lines pointing at the text instead.
      #: () -> Hash[String, untyped]
      def shown
        lines = @member_lines
        return lines.merge("now" => in_text(1, lines.fetch("now"))) if lines["now"].is_a?(Array)
        return lines.merge("changed_region" => region(lines.fetch("changed_region"))) if lines["changed_region"]
        return lines.merge("changed_regions" => lines.fetch("changed_regions").map { region(it) }) if
          lines["changed_regions"]

        lines
      end

      private

      # A changed region, its side now pointing at the text when it lists its lines.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def region(changed)
        now = changed.fetch("now")
        now["lines"] ? changed.merge("now" => in_text(now.fetch("from_line"), now.fetch("lines"))) : changed
      end

      # Where lines start in the text, and how many they are.
      #: (Integer, Array[String]) -> Hash[String, Integer]
      def in_text(from_line, lines) = { "from_line" => from_line, "lines_in_text" => lines.length }
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "evidence_item"
require_relative "located_text"
require_relative "line_span"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The lines a full audit's members span now, each with its file, against which each evidence item of another
    # principle's open finding is said to share lines or not. These are lines, not a verdict on whether
    # the finding is about the same problem, which the agent judges.
    class AuditedMemberLines
      # located gives, under each audited member's id, the text found for it now: its path and its lines.
      #: (Hash[String, LocatedText]) -> void
      def initialize(located)
        @spans = located.transform_values { |found| [found.path, found.span] } #: Hash[String, [String, LineSpan]]
        freeze
      end

      # The item as the record keeps it, with what its lines are now beside these members': the members whose lines it
      # shares, or that it shares none, with its lines; that it names only a whole file; or that locate, which finds
      # it in its file now, can no longer find it, so one moved write-up never refuses the request.
      #: (EvidenceItem) { (Locator) -> LocatedText } -> Hash[String, untyped]
      def facts_of(item, &locate)
        return item.with_facts("whole_file" => true) if item.whole_file?

        span = locate.call(item.locator).span
        item.with_facts("first_line" => span.first_line, "last_line" => span.last_line, **sharing(item.path, span))
      rescue Error
        item.with_facts("not_located" => true)
      end

      private

      #: (String, LineSpan) -> Hash[String, untyped]
      def sharing(path, span)
        ids = @spans.select { |_, (on, member)| on == path && member.shares_a_line_with?(span) }.keys
        ids.empty? ? { "shares_no_lines" => true } : { "shares_lines_with" => ids }
      end
    end
  end
end

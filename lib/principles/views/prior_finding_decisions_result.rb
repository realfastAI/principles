# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How a completed full audit's result says what it decided about each prior finding.
    class PriorFindingDecisionsResult
      # kept_ids are the prior findings it kept and closed those it closed; changed is what the decisions changed of
      # the findings kept, each list by the name the result gives it after prior_findings_: pointers_dropped, any
      # pointer a decision dropped, waits_on_dropped, any waits_on it dropped, with null or by accepting it,
      # evidence_replaced, each kept evidence item a decision gave a new place, as it was and is now, and
      # problems_restated, each problem a decision restated, as it was and is now.
      #: (kept_ids: Array[String], closed: Array[Hash[String, untyped]],
      #|  changed: Hash[String, Array[Hash[String, untyped]]]) -> void
      def initialize(kept_ids:, closed:, changed:)
        @kept_ids = kept_ids
        @closed = closed
        @changed = changed
        freeze
      end

      # output, with these decisions added, and each list of changes that is not empty; unchanged when there were no
      # prior findings to decide.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def added_to(output)
        return output if @kept_ids.empty? && @closed.empty?

        changes = @changed.reject { |_, list| list.empty? }.transform_keys { |name| "prior_findings_#{name}" }
        output.merge("prior_findings_kept" => @kept_ids, "prior_findings_closed" => @closed, **changes)
      end
    end
  end
end

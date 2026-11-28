# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member_moves"
require_relative "recorded_finding"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What the next full audit decided about each prior finding, once this tool has checked the decisions:
    # the findings that still hold, as the record keeps them; the ones closed, with their reasons; and, for each
    # new finding that raises a prior one again, when that one was first raised. The correction's basis carries
    # these fields, so an audit with findings completes with the same decisions.
    class DecidedPriorFindings
      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields.freeze #: Hash[String, untyped]
        freeze
      end

      # Whether there was no prior finding to decide.
      #: () -> bool
      def none?
        kept.empty? && closed.empty? && @fields.fetch("inherited").empty?
      end

      # Each finding that still holds, as the record keeps it.
      #: () -> Array[Hash[String, untyped]]
      def kept
        @fields.fetch("kept")
      end

      #: () -> Array[String]
      def kept_ids = kept_findings.map(&:id)

      # Refuses a new finding that reuses the id of a prior finding that still holds, since the record would then hold
      # two findings under one id.
      #: (Array[String]) -> void
      def distinct_from(new_ids)
        return unless kept_ids.intersect?(new_ids)

        raise Error.new("duplicate_finding", "A new finding reuses the id of a prior finding that still holds",
                        "Give new findings ids other than the kept ones: #{kept_ids.join(", ")}.")
      end

      # Each finding resolved or withdrawn, with its decision and reason.
      #: () -> Array[Hash[String, untyped]]
      def closed
        @fields.fetch("closed")
      end

      # The ids of the prior findings decided resolved; a withdrawn one was never a gap.
      #: () -> Array[String]
      def resolved_ids = closed.select { |each| each["decision"] == "resolved" }.map { |each| each.fetch("finding_id") }

      # What the decisions changed of the findings kept, each list by the name the completed result gives it after
      # prior_findings_: each pointer a decision dropped with null, with the pointer it had; each waits_on it
      # dropped, with null or by accepting it, with the line and since it had; each kept evidence item it gave a
      # new place; and each problem it restated, each as it was and is now. A correction basis printed
      # before a list was built carries none of it.
      #: () -> Hash[String, Array[Hash[String, untyped]]]
      def changed
        { "pointers_dropped" => @fields.fetch("dropped", []),
          **%w[waits_on_dropped evidence_replaced problems_restated].to_h { |name| [name, @fields.fetch(name, [])] } }
      end

      # When the prior finding that the new finding id raises again was first raised, or nothing.
      #: (String) -> Hash[String, String]
      def first_raised(id)
        inherited = @fields.fetch("inherited")
        inherited.key?(id) ? { "first_raised_at" => inherited.fetch(id) } : {}
      end

      # Where each deferral raised again was written up and whom it waited on, by the id of the new finding it became;
      # none in a basis printed before they were carried.
      #: () -> Hash[String, Hash[String, untyped]]
      def deferrals_raised_again = @fields.fetch("deferrals_raised_again", {})

      # These decisions with each kept finding filed under its members' ids after moves.
      #: (MemberMoves) -> DecidedPriorFindings
      def moved(moves)
        DecidedPriorFindings.new(@fields.merge("kept" => moves.findings(kept)))
      end

      # The fields as the correction's basis carries them.
      #: () -> Hash[String, untyped]
      def to_h
        @fields
      end

      NONE = new({ "kept" => [], "closed" => [], "inherited" => {} }) #: DecidedPriorFindings

      private

      # Each finding that still holds, read as the record keeps it.
      #: () -> Array[RecordedFinding]
      def kept_findings = kept.map { |finding| RecordedFinding.new(finding) }
    end
  end
end

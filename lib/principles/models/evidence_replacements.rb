# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "locator"
require_relative "answer_fields"
require_relative "answer_place"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The new places a still_holds decision gives a kept finding's evidence items that are no longer found, each
    # problem_evidence entry naming by replaces the position of the item it replaces. An item still found stays
    # as the audit raised it, so a decision never rewrites what an audit found; git keeps the old pointer.
    class EvidenceReplacements
      # The field an entry names the kept item it replaces by, which the record does not keep.
      REPLACES = "replaces"

      # kept is the finding's evidence as its record keeps it, in order; entries are the decision's problem_evidence.
      #: (Array[Hash[String, untyped]], Array[Hash[String, untyped]]) -> void
      def initialize(kept, entries)
        @kept = kept
        @entries = entries
        freeze
      end

      # Refuses, through refuse with a reason and a repair, an entry that names no kept item by replaces, names one
      # twice, or names one locate still finds, and has locate find each new pointer, at place.
      #: (^(Locator) -> void, String, AnswerPlace, refuse: ^(String, String?) -> void) -> void
      def check(locate, id, place, refuse:)
        positions(id, refuse)
        @entries.each do |entry|
          index = entry.fetch(REPLACES)
          next unless found?(locate, @kept.fetch(index))

          refuse.call("evidence item #{index} is still found, so a decision may not replace it",
                      "Drop that entry from #{id}'s problem_evidence, or raise it again as a new finding to " \
                      "restate its evidence.")
        end
        AnswerFields.new(locate).evidence(pointers, place)
      end

      # The evidence the record keeps: each kept item, with each one an entry names swapped for its new pointer.
      #: () -> Array[Hash[String, untyped]]
      def evidence
        by_index = @entries.to_h { |entry| [entry.fetch(REPLACES), entry.except(REPLACES)] }
        @kept.each_with_index.map { |item, index| by_index.fetch(index, item) }
      end

      # Each swap, as the completed result names it for finding id: the pointer replaced and its new one.
      #: (String) -> Array[Hash[String, untyped]]
      def swaps(id)
        @entries.map do |entry|
          { "finding_id" => id, "replaced" => @kept.fetch(entry.fetch(REPLACES)), "with" => entry.except(REPLACES) }
        end
      end

      private

      # The new pointers, as their record keeps them.
      #: () -> Array[Hash[String, untyped]]
      def pointers = @entries.map { |entry| entry.except(REPLACES) }

      # Refuses an entry without replaces, one naming no kept item, and two naming the same one.
      #: (String, ^(String, String?) -> void) -> void
      def positions(id, refuse)
        named = @entries.map { |entry| entry[REPLACES] }
        unnamed(id, refuse) if named.any?(nil)
        stray = named.grep_v(0...@kept.size).first
        if stray
          refuse.call(stray_problem(stray),
                      "Name by replaces a position in #{id}'s evidence, from 0 to #{@kept.size - 1}.")
        end
        twice = named.find { |index| named.count(index) > 1 } or return
        refuse.call("replaces names evidence item #{twice} twice",
                    "Give each item of #{id}'s evidence at most one entry in its problem_evidence.")
      end

      # What is wrong with a replaces naming no kept item: text is only ever the template's placeholder, which the
      # answer's schema lets through for it.
      #: (untyped) -> String
      def stray_problem(stray)
        stray.is_a?(String) ? "replaces is left as printed" : "replaces #{stray} names no item of its evidence"
      end

      # Refuses entries that do not say which kept item each replaces, since the record keeps the evidence it was
      # raised with.
      #: (String, ^(String, String?) -> void) -> void
      def unnamed(id, refuse)
        refuse.call("its record keeps the evidence it was raised with, so each problem_evidence entry must name by " \
                    "replaces the item no longer found that it replaces",
                    "Give each entry replaces, the position in #{id}'s evidence of an item no longer found, " \
                    "counting from 0, or drop problem_evidence.")
      end

      # Whether locate finds item now.
      #: (^(Locator) -> void, Hash[String, untyped]) -> bool
      def found?(locate, item)
        locate.call(Locator.new(item))
        true
      rescue Error
        false
      end
    end
  end
end

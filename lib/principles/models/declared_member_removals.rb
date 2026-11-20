# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member_moves"
require_relative "principle"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The set of members fixed dispositions say they removed from the map, never from their source files.
    class DeclaredMemberRemovals
      #: (untyped) -> void
      def initialize(dispositions)
        claimed = Array(dispositions).flat_map { |each| claimed(each) }
        @ids = claimed.uniq.map { |id| id.dup.freeze }.freeze #: Array[String]
        freeze
      end

      #: () -> bool
      def empty? = @ids.empty?

      # A removal cannot simultaneously claim to move or edit that same map entry.
      #: (MemberMoves, Array[String]) -> void
      def check_conflicts(moves, entries)
        return unless moves.involving_any?(@ids) || @ids.intersect?(entries)

        raise invalid("A removed member also appears in moved_members or changed_map_entries")
      end

      # Apply only removals that really existed in the original map and are absent from the current one.
      #: (Principle, Principle) -> Principle
      def applied(base, current)
        unless (@ids - base.members.ids).empty? && !@ids.intersect?(current.members.ids)
          raise invalid("Each removed_members id must exist at the audit base and be absent now")
        end

        @ids.reduce(base) { |map, id| map.removing(id) }
      end

      # Called after complete map equality, so an unexplained removal retains its ordinary stale-map refusal.
      #: (Principle) -> void
      def check_endpoint(current)
        return if empty? || current.members.ids.any?

        raise Error.new("empty_correction_map", "A declared-removal correction must leave a mapped member",
                        "Keep a survivor or add a replacement. Restore the removed map entries before " \
                        "reconsidering or deferring the correction. Preserve the correction packet; " \
                        "it has not been submitted. Explicit deactivation retains the previous audit history:\n" \
                        "#{Error::EXECUTABLE} remove-principle #{current.id}")
      end

      private

      #: (untyped) -> Array[String]
      def claimed(disposition)
        return [] unless disposition.is_a?(Hash)

        ids = disposition.fetch("removed_members", [])
        if !ids.empty? && disposition["action"] != "fixed"
          raise Error.new("invalid_disposition", "Only a fixed disposition may list removed_members",
                          "Mark it fixed with evidence and a reassessment, or omit removed_members.")
        end
        ids
      end

      #: (String) -> Error
      def invalid(message)
        Error.new("invalid_removed_members", message,
                  "List only actual map removals in each fixed disposition's removed_members; " \
                  "keep them disjoint from moves and changed_map_entries. Source files are never removed.")
      end
    end
  end
end

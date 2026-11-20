# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_text"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The fields of a disposition that only a fix uses, changed_members, changed_map_entries, evidence and
    # reassessment, and what its action allows of them: a fix gives them, and any other action may omit them, or leave
    # them as printed, and claims no change.
    class FixOnlyFields
      # disposition is the disposition as the agent gave it; left_reassessment is the reassessment its template
      # prints, which a disposition not fixed leaves as printed.
      #: (Hash[String, untyped], left_reassessment: String) -> void
      def initialize(disposition, left_reassessment:)
        @disposition = disposition
        @left_reassessment = left_reassessment
        freeze
      end

      # The list field name gives, as given, or an empty list when a disposition not fixed omits it; a fix omitting
      # it is refused, naming the field.
      #: (String) -> untyped
      def list(name) = @disposition.fetch(name) { fixed? ? missing_from_fix(name) : [] }

      # A removal without current text or role/check changes needs located evidence about what remains.
      #: () -> void
      def check_removal_evidence
        return if @disposition.fetch("removed_members", []).empty?
        return unless list("changed_members").empty? && @disposition.fetch("changed_map_entries", []).empty?
        return unless list("evidence").empty?

        raise Error.new("invalid_disposition", "A removal-only fix needs evidence about the remaining guidance",
                        "Give at least one located evidence pointer about the remaining guidance and " \
                        "write a substantive reassessment.")
      end

      # The members a disposition not fixed claims, none, refusing one that lists changed members or map entries,
      # writes a reassessment or lists evidence, each of which it would drop unread though the agent may have meant
      # a fix.
      #: (Array[untyped], Array[untyped]) -> Array[untyped]
      def unclaimed(members, entries)
        unless entries.empty?
          raise Error.new("invalid_disposition", "Only a fixed disposition may list changed_map_entries",
                          "Mark it fixed with a reassessment, or omit changed_map_entries.")
        end
        fix_text_unclaimed
        return [] if members.empty?

        raise Error.new("invalid_disposition", "Only a fixed disposition may claim changed members",
                        "Mark it fixed with a reassessment, or omit changed_members.")
      end

      private

      #: () -> bool
      def fixed? = @disposition["action"] == "fixed"

      #: (String) -> bot
      def missing_from_fix(name)
        raise Error.new("invalid_disposition", "Finding #{@disposition["finding_id"]} is fixed, so it needs #{name}",
                        "List in #{name} what the fix changed, or choose another action.")
      end

      # Refuses a reassessment written, or evidence listed, on a disposition not fixed; each left as printed is not
      # given.
      #: () -> void
      def fix_text_unclaimed
        reassessment = @disposition["reassessment"]
        written = reassessment != @left_reassessment && AnswerText.new(reassessment).written?
        field = ("reassessment" if written) || ("evidence" unless list("evidence").empty?) or return
        raise Error.new("invalid_disposition", "Only a fixed disposition may give #{field}",
                        "Mark it fixed, or leave #{field} as printed.")
      end
    end
  end
end

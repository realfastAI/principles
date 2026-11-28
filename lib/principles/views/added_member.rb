# typed: strict
# frozen_string_literal: true

require_relative "lines_shared_with_member"
require_relative "consecutive_sections_elsewhere"
require_relative "whole_file_elsewhere"
require_relative "member_sets_overlap"

module Principles
  module Views
    # The member just added: its id, current lines and check, beside its shared-line facts and the facts of other
    # maps it asks the agent to judge, each printed only when it has some.
    class AddedMember
      # What the agent decides when other principles hold the new member's file whole or a nearly matching member set,
      # asked once however many of those cues fire.
      SCOPE_OR_JOIN = "Should each hold only the passages that carry it (move-member with " \
                      "--section or --starting-at), or are they one principle (join the maps: add one map's " \
                      "members to the other, then remove-principle)? " #: String

      #: (Hash[String, untyped], shared: LinesSharedWithMember,
      #|  other_maps: Array[ConsecutiveSectionsElsewhere | WholeFileElsewhere | MemberSetsOverlap])
      #|  -> void
      def initialize(added, shared:, other_maps:)
        facts = other_maps.reduce(added.merge(shared.to_h)) { |merged, each| merged.merge(each.to_h) }
        @added = facts #: Hash[String, untyped]
        @shared = shared
        @other_maps = other_maps
        freeze
      end

      #: () -> String
      def id = @added.fetch("id")

      #: () -> Hash[String, untyped]
      def to_h = @added

      # The same location/remapping opening precedes the map's own after-add guidance.
      #: () -> String
      def opening
        "#{span}#{@shared.note}#{@other_maps.map(&:note).join}#{SCOPE_OR_JOIN if scope_or_join?}" \
          "Add the next member the same way. "
      end

      private

      #: () -> bool
      def scope_or_join? = @other_maps.any?(&:asks_scope_or_join?)

      # The lines a member spans, said so that a passage cut short shows; it ends with a space.
      #: () -> String
      def span
        "#{id} spans lines #{@added.fetch("first_line")} to #{@added.fetch("last_line")}; " \
          "if that is not the passage you meant, move it with move-member. #{runs_on}"
      end

      # What the agent judges when the paragraph or list item a one-line passage starts runs on past it; it ends with
      # a space, or is empty.
      #: () -> String
      def runs_on
        line = @added["continues_to_line"] or return ""
        "Its paragraph or list item continues to line #{line}; if the member is all of it, move it with " \
          "--ending-at quoting the words that end it. "
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "lines_shared_with_member"
require_relative "consecutive_sections_elsewhere"

module Principles
  module Views
    # The member just added: its id, current lines and check, beside its shared/consecutive location facts.
    class AddedMember
      #: (Hash[String, untyped], shared: LinesSharedWithMember, consecutive: ConsecutiveSectionsElsewhere) -> void
      def initialize(added, shared:, consecutive:)
        @added = added.merge(shared.to_h).merge(consecutive.to_h) #: Hash[String, untyped]
        @shared = shared
        @consecutive = consecutive
        freeze
      end

      #: () -> String
      def id = @added.fetch("id")

      #: () -> Hash[String, untyped]
      def to_h = @added

      # The same location/remapping opening precedes the map's own after-add guidance.
      #: () -> String
      def opening
        "#{span}#{@shared.note}#{@consecutive.note}Add the next member the same way. "
      end

      private

      # The lines a member spans, said so that a passage cut short shows; it ends with a space.
      #: () -> String
      def span
        "#{id} spans lines #{@added.fetch("first_line")} to #{@added.fetch("last_line")}; " \
          "if that is not the passage you meant, move it with move-member. "
      end
    end
  end
end

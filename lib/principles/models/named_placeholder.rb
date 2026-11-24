# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A placeholder a template prints naming the id of the slot it fills, a member's or a finding's, or the slot's
    # position, so no two slots are alike and a file-edit tool's one-match replace fills one. Its text for any id, or
    # the text it printed before, sent in any slot, is left as printed: a plain text, or an earlier NamedPlaceholder
    # with its own earlier text, so an answer filled from any release's template is read alike.
    class NamedPlaceholder
      # The slot in slotted that each slot's id fills.
      SLOT = "%<id>s" #: String

      # slotted is the text with SLOT where the id goes; before is the text it printed before, plain or named.
      #: (String, before: String | NamedPlaceholder) -> void
      def initialize(slotted, before:)
        @slotted = slotted
        @before = before
        @pattern = /\A#{Regexp.escape(slotted).sub(Regexp.escape(SLOT), ".+")}\z/m #: Regexp
        freeze
      end

      # The text with SLOT, which a controller hands the view that fills each slot's id.
      #: String
      attr_reader :slotted

      # Whether text is this placeholder, for any id or as it was printed before.
      #: (untyped) -> bool
      def left?(text) = (text.is_a?(String) && @pattern.match?(text)) || earlier?(text)

      private

      # Whether text is the placeholder as it was printed before.
      #: (untyped) -> bool
      def earlier?(text)
        earlier = @before
        earlier.is_a?(NamedPlaceholder) ? earlier.left?(text) : text == earlier
      end
    end
  end
end

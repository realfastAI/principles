# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # A member id an answer named that the map does not hold. A member id copies its heading exactly, so
    # an agent typing it may use a straight apostrophe for a curly one, a hyphen for a dash, or other
    # case and spacing (alpha 011 friction 12). This finds the mapped id it differs from only so, to name
    # in the refusal; this tool never accepts the misspelt id itself.
    class MisspeltMemberId
      APOSTROPHES = /[‘’‚‛′ʼ`´]/
      QUOTES = /[“”„‟″]/
      DASHES = /[‐-―−]/

      #: (String) -> void
      def initialize(id)
        @id = id
        freeze
      end

      # The one mapped id spelled like this one apart from punctuation, case and spacing, or nil.
      #: (Array[String]) -> String?
      def closest(mapped)
        matches = mapped.select { |each| loose(each) == loose(@id) }
        matches.first if matches.one?
      end

      # What a refusal says of this id: that it is not mapped, and the mapped id it is spelled like; nil when none.
      #: (Array[String]) -> String?
      def hint(mapped)
        closest = closest(mapped) or return nil
        "#{@id} is not mapped; did you mean #{closest}?"
      end

      private

      #: (String) -> String
      def loose(text)
        text.unicode_normalize(:nfkc).gsub(APOSTROPHES, "'").gsub(QUOTES, '"').gsub(DASHES, "-")
            .downcase.split.join(" ")
      end
    end
  end
end

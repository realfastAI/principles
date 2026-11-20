# typed: strict
# frozen_string_literal: true

require_relative "request_part"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A judgement request's parts beyond its members, in the order the agent reads them.
    class RequestParts
      #: (Array[RequestPart]) -> void
      def initialize(parts)
        @parts = parts
        freeze
      end

      # entries, with what each part shows added after them, in order.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def shown_after(entries) = @parts.reduce(entries) { |all, part| all.merge(part.shown) }

      # Every part's instructions, in order.
      #: () -> Array[Instruction]
      def instructions = @parts.flat_map(&:instructions)

      # template, with each part's slots added after its own entries, in order.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def slotted_after(template) = @parts.reduce(template) { |all, part| all.merge(part.slots) }

      # template, with each part's slots added after its own entries, in order, each carrying its help.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def filled_after(template) = @parts.reduce(template) { |all, part| all.merge(part.slots_to_fill) }
    end
  end
end

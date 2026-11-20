# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"
require_relative "principle"
require_relative "mapped_principles"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One exact source identity/revision named by a supported linked map, distinct from legacy unknown metadata.
    class PrinciplePredecessor
      #: (Principle, principles: MappedPrinciples) -> PrinciplePredecessor?
      def self.from(current, principles:)
        marker = current.to_h.fetch("format", 1)
        return nil if marker.is_a?(Integer) && (1..2).cover?(marker)

        checked = principles.parsed_history(current.id, JSON.generate(current.to_h), commit: nil)
        return nil unless checked.to_h["format"] == 3

        new(current.id, checked.to_h.fetch("predecessor"), principles.file(current.id))
      end

      #: String
      attr_reader :principle_id, :commit

      #: (String, Hash[String, untyped], String) -> void
      def initialize(target, fields, path)
        @principle_id = fields.fetch("principle_id").dup.freeze #: String
        @commit = fields.fetch("commit").dup.freeze #: String
        if @principle_id == target
          raise Error.new("invalid_map", "#{target} cannot name itself as its immediate predecessor",
                          "Restore the exact predecessor from a supported ID change. Preserve map and audit files " \
                          "for inspection.", path)
        end
        freeze
      end
      private_class_method :new

      #: () -> Hash[String, String]
      def to_h = { "principle_id" => @principle_id, "commit" => @commit }.freeze
    end
  end
end

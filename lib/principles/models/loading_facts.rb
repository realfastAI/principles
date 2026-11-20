# typed: strict
# frozen_string_literal: true

require_relative "member_loads"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What a member's loads say about when it loads and what, at any depth, without the file's or the member's size.
    # A file's size moves with every edit elsewhere in a shared file, so a judgement weighed on a member's loading
    # compares these facts, not the sizes.
    class LoadingFacts
      # loads is a member's loads as MemberLoads#to_h gives them, or as a record keeps them.
      #: (Hash[String, untyped]) -> void
      def initialize(loads)
        @facts = without_sizes(loads) #: untyped
        freeze
      end

      #: () -> untyped
      def to_h = @facts

      #: (untyped) -> bool
      def ==(other) = other.is_a?(LoadingFacts) && other.to_h == @facts

      alias eql? ==

      #: () -> Integer
      def hash = @facts.hash

      private

      #: (untyped) -> untyped
      def without_sizes(value)
        case value
        when Hash
          value.except(*MemberLoads::FILE_SIZE_FIELDS, *MemberLoads::MEMBER_SIZE_FIELDS)
               .transform_values { |each| without_sizes(each) }
        when Array then value.map { |each| without_sizes(each) }
        else value
        end
      end
    end
  end
end

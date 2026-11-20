# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The selector * in a JSONPath query: every member value of an object, or every element of an array.
    class JsonPathWildcard
      #: () -> void
      def initialize
        freeze
      end

      #: (untyped) -> Array[untyped]
      def select(node)
        return node.values if node.is_a?(Hash)

        node.is_a?(Array) ? node : []
      end
    end

    # A name selector in a JSONPath query: the member of an object with that name, if it has one.
    class JsonPathName
      #: String
      attr_reader :name

      #: (String) -> void
      def initialize(name)
        @name = name
        freeze
      end

      #: (untyped) -> Array[untyped]
      def select(node)
        node.is_a?(Hash) && node.key?(@name) ? [node.fetch(@name)] : []
      end
    end

    # A filter selector in this tool's profile: the children for which every condition holds, each condition an
    # @-relative path of names leading to a string equal to the condition's string.
    class JsonPathFilter
      #: (Array[[Array[String], String]]) -> void
      def initialize(conditions)
        @conditions = conditions
        freeze
      end

      #: (untyped) -> Array[untyped]
      def select(node)
        JsonPathWildcard.new.select(node).select { |child| holds_for?(child) }
      end

      private

      #: (untyped) -> bool
      def holds_for?(child)
        @conditions.all? do |path, expected|
          found = path.reduce(child) { |value, name| value.is_a?(Hash) ? value[name] : nil }
          found.is_a?(String) && found == expected
        end
      end
    end
  end
end

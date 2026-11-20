# typed: strict
# frozen_string_literal: true

require_relative "../prose_list"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The type one schema asks for, from its type keyword: whether a value has it, and how a refusal names it,
    # with the keys an object takes, so an agent that sent another type learns the shape from the refusal.
    class ExpectedType
      TYPES = {
        "object" => Hash, "array" => Array, "string" => String, "integer" => Integer, "boolean" => [true, false],
        "null" => NilClass
      }.freeze #: Hash[String, untyped]
      # This tool's own schema keyword: what a refusal of the value's type adds, such as when to point inside a
      # file, which the keys alone do not say, as {"keys", "says"}. The refusal says it after the required
      # keys, in place of the optional keys it names, so it names each key once.
      ADVICE = "x-type-refusal-advice"

      #: (Hash[String, untyped]) -> void
      def initialize(schema)
        advice = schema.fetch(ADVICE, {}) #: Hash[String, untyped]
        @names = Array(schema["type"]) #: Array[String]
        @required = schema.fetch("required", []) #: Array[String]
        @optional = schema.fetch("properties", {}).keys - @required - advice.fetch("keys", []) #: Array[String]
        @advice = advice["says"] #: String?
        freeze
      end

      # Whether value has the type; a schema that names no type allows any.
      #: (untyped) -> bool
      def matches?(value)
        @names.empty? || @names.any? do |name|
          kind = TYPES.fetch(name)
          kind.is_a?(Array) ? kind.include?(value) : value.is_a?(kind)
        end
      end

      # The type as a refusal says it, such as "an object or null, with path and optionally heading", with any
      # advice the schema gives for it.
      #: () -> String
      def to_s
        @names.map { |name| %w[object array integer].include?(name) ? "an #{name}" : "a #{name}" }
              .join(" or ").sub("a null", "null") + keys
      end

      private

      # The keys an object takes: its required ones, then the advice, then the others it may take.
      #: () -> String
      def keys
        return any_of if @required.empty?

        text = [", with #{ProseList.new(@required)}", *@advice].join(", ")
        return text if @optional.empty?

        "#{text}#{"," if @advice} and optionally #{optional}"
      end

      # The keys an object that requires none may take, then the advice; nothing when there are neither.
      #: () -> String
      def any_of
        [*("with any of #{optional}" unless @optional.empty?), *@advice].sum("") { |part| ", #{part}" }
      end

      #: () -> ProseList
      def optional = ProseList.new(@optional, conjunction: "or")
    end
  end
end

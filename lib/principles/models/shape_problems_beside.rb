# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The problems an answer's shape has beside those a refusal before the shape names, which that refusal names too,
    # so one refusal lists every repair, and says so in its message, which an agent reads first.
    class ShapeProblemsBeside
      # What the message adds when there are any.
      MESSAGE = ", and fields not in the shape this tool reads" #: String

      # problems are the shape's, as Data::SchemaCheck#problems gives them; each at or under a pointer in named, which
      # the refusal names, is left out, since its repair repairs that one too.
      #: (Array[Hash[String, String]], named: Array[String]) -> void
      def initialize(problems, named:)
        elsewhere = problems.reject { |problem| under?(problem.fetch("pointer"), named) }
        @fields = elsewhere.freeze #: Array[Hash[String, String]]
        freeze
      end

      #: Array[Hash[String, String]]
      attr_reader :fields

      # The refusal's own message, saying when it names these too.
      #: (String) -> String
      def message(own) = "#{own}#{MESSAGE unless @fields.empty?}"

      # The refusal's own repair, with also, how to repair these, when there are any.
      #: (String, String) -> String
      def repair(own, also) = "#{own}#{also unless @fields.empty?}"

      private

      # Whether pointer is one of named, or inside one.
      #: (String, Array[String]) -> bool
      def under?(pointer, named) = named.any? { pointer == it || pointer.start_with?("#{it}/") }
    end
  end
end

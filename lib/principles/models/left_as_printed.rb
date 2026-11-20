# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "shape_problems_beside"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The judgements an answer leaves as its template printed them, each named with its pointer, which the answer
    # refuses in one refusal, so a copied template takes one repair.
    class LeftAsPrinted
      # The problem with a judgement sent back as its placeholder.
      UNCHANGED = "is the template's placeholder, unchanged" #: String

      # pointers holds each judgement left as printed, by its name, with its JSON pointer.
      #: (Hash[String, String]) -> void
      def initialize(pointers)
        @pointers = pointers.freeze #: Hash[String, String]
        freeze
      end

      # Refuses the answer naming each judgement left as printed, then each of besides, problems its shape has
      # elsewhere, so one refusal names every repair; one at or under a pointer named is left out, since
      # writing the judgement repairs it. Nothing when none is left as printed, so the shape's own refusal names them.
      #: (?besides: Array[Hash[String, String]]) -> void
      def refuse(besides: [])
        return if @pointers.empty?

        elsewhere = ShapeProblemsBeside.new(besides, named: @pointers.values)
        raise Error.new("invalid_answer", elsewhere.message("Still to write: #{ProseList.new(@pointers.keys)}"),
                        "#{elsewhere.repair("Replace each placeholder named in fields with your own judgement",
                                            ", and repair each other field listed there")}.",
                        fields: @pointers.values.map { { "pointer" => it, "problem" => UNCHANGED } } + elsewhere.fields)
      end
    end
  end
end

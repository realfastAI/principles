# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "locator"
require_relative "answer_place"
require_relative "answer_text"
require_relative "write_up_pointer"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The checks every answer's fields share: a field is a nonempty string or an array, and each piece of
    # evidence names a path that the caller's block locates in the project.
    class AnswerFields
      #: (^(Locator) -> void) -> void
      def initialize(locate)
        @locate = locate
      end

      #: (untyped, String) -> String
      def text(value, field) = AnswerText.new(value).required(field)

      # value as text, refused as field at its place in the answer, so one of many entries is found.
      #: (untyped, String, AnswerPlace) -> String
      def text_at(value, field, place)
        text(value, field)
      rescue Error => e
        raise place.refusal(e)
      end

      #: (untyped, String) -> untyped
      def array(value, field)
        unless value.is_a?(Array)
          raise Error.new("invalid_answer", "#{field} must be an array",
                          "Supply #{field} as the question asks.")
        end

        value
      end

      # Each piece of evidence, located where place says the answer holds it; a refusal locating one names its place.
      #: (untyped, AnswerPlace) -> void
      def evidence(references, place)
        array(references, "evidence").each_with_index { |reference, index| pointer(reference, place.child(index)) }
      end

      # One pointer into the project, such as where a finding is written up, located at its place in the answer.
      #: (untyped, AnswerPlace) -> void
      def pointer(reference, place)
        text(reference["path"], "evidence.path")
        begin
          @locate.call(Locator.new(reference))
        rescue Error => e
          raise place.refusal(e)
        end
      end

      # Where a finding is written up, located at its place in the answer, as the value its record keeps.
      #: (untyped, AnswerPlace) -> WriteUpPointer
      def write_up_pointer(reference, place)
        pointer(reference, place)
        WriteUpPointer.new(reference)
      end
    end
  end
end

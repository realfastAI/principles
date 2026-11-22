# typed: strict
# frozen_string_literal: true

require_relative "left_as_printed"
require_relative "named_placeholder"
require_relative "refusal_before_shape"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The text an answer's template prints in each field an agent may leave as printed to give none, so the agent
    # fills the fields that apply and never reshapes the answer. The model that owns a part of the answer
    # holds one, which a controller hands to the view that prints it.
    class TemplatePlaceholders
      include RefusalBeforeShape

      # placeholders is the text printed in each field, by field name, or for a field that takes pointers, one pointer
      # whose fields hold that text, so the template shows their shape; empty_lists names the fields a template
      # may instead start as an empty list, which is not given either; also_printed, the other text a template
      # may print in a field, refused alike. A NamedPlaceholder in either prints with its slot, which the view fills
      # with the id of the entry it prints in, and is left as printed for any id.
      #: (Hash[String, untyped], ?empty_lists: Array[String], ?also_printed: Hash[String, untyped]) -> void
      def initialize(placeholders, empty_lists: [], also_printed: {})
        @placeholders = placeholders.freeze #: Hash[String, untyped]
        @empty_lists = empty_lists.freeze #: Array[String]
        @also_printed = also_printed.freeze #: Hash[String, untyped]
        freeze
      end

      # The text printed in each field, with field's other text in place of its own.
      #: (String) -> Hash[String, untyped]
      def with_other_text_in(field) = to_h.merge(field => shown(@also_printed.fetch(field)))

      # Each placeholder printed in its own field naming its entry's id; a field's other text is printed only by
      # some of its requests, so another template leaving it is not read as this one's.
      #: () -> Array[NamedPlaceholder]
      def named = @placeholders.values.grep(NamedPlaceholder)

      # The text printed in each field, for the view that prints it.
      #: () -> Hash[String, untyped]
      def to_h = @placeholders.transform_values { shown(it) }

      # The text printed in field.
      #: (String) -> untyped
      def fetch(field) = shown(@placeholders.fetch(field))

      # fields, without each one left as its placeholder, which is not given.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def given(fields) = fields.reject { |field, value| left?(field, value) }

      # Refuses answer, as sent, when it leaves a field as its placeholder, for a template whose every field must be
      # written, as a one-member audit's; read before the answer's shape, which would refuse a placeholder in a
      # field of another type without naming it, so the refusal names the shape's other problems too. source
      # is unused, as other refusals before the shape name it.
      # @override
      #: (untyped, String, Array[Hash[String, String]]) -> void
      def refuse_in(answer, _source, shape_problems)
        return unless answer.is_a?(Hash)

        left = @placeholders.keys.select { |field| printed?(field, answer[field]) }
        LeftAsPrinted.new(left.to_h { [it, "/#{it}"] }).refuse(besides: shape_problems)
      end

      # Whether value is field's placeholder, or the empty list it may start as, as printed; a field with neither
      # never is.
      #: (String, untyped) -> bool
      def left?(field, value)
        (@placeholders.key?(field) && printed?(field, value)) || (@empty_lists.include?(field) && value == [])
      end

      private

      # Whether value is a text the template prints in field.
      #: (String, untyped) -> bool
      def printed?(field, value)
        [@placeholders[field], @also_printed[field]].compact.any? do |printed|
          printed.is_a?(NamedPlaceholder) ? printed.left?(value) : printed == value
        end
      end

      # placeholder as the template prints it, a NamedPlaceholder with its slot.
      #: (untyped) -> untyped
      def shown(placeholder) = placeholder.is_a?(NamedPlaceholder) ? placeholder.slotted : placeholder
    end
  end
end

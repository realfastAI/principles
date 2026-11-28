# typed: strict
# frozen_string_literal: true

require_relative "answer_place"
require_relative "answer_text"
require_relative "named_placeholder"
require_relative "unfinished_field"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A text field the agent must write: the placeholder the correction template leaves in it, which an answer may
    # not send back unchanged, and what to write instead; reassessment applies only to a fix.
    class DispositionTextField
      # The problem with a field the agent gave back as the answer guide's sample.
      SAMPLE_UNCHANGED = "is the answer guide's sample, unchanged" #: String

      # The placeholder, naming the finding of the disposition it is printed in.
      #: NamedPlaceholder
      attr_reader :placeholder

      # What to write instead.
      #: String
      attr_reader :repair

      #: (placeholder: NamedPlaceholder, repair: String) -> void
      def initialize(placeholder:, repair:)
        @placeholder = placeholder
        @repair = repair
        freeze
      end

      # The field named name, at place, when value leaves it empty, as the placeholder for any finding or as sample,
      # the answer guide's illustration of this field for the disposition's action, if it gives one.
      #: (untyped, AnswerPlace, String, sample: String?) -> UnfinishedField?
      def left_in(value, place, name, sample:)
        problem = if !AnswerText.new(value).written? then "must be a nonempty string"
                  elsif @placeholder.left?(value) then "is the template's placeholder, unchanged"
                  elsif value == sample then SAMPLE_UNCHANGED
                  end
        UnfinishedField.new(place, name, problem:, repair: @repair) if problem
      end
    end
  end
end

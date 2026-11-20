# typed: strict
# frozen_string_literal: true

require_relative "answer_fields"
require_relative "recorded_finding"
require_relative "write_up_pointer"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One finding's write-up pointer moved by a repoint: the finding it names, the recorded_at the agent
    # found the write-up at, and why. It moves a finding there, keeping where it pointed before, when and why.
    class WriteUpRepoint
      # The repoint one entry of an answer's repoints gives, to recorded_at, its pointer already located, refused by
      # fields without a reason, since the record keeps why each pointer moved, naming its place in the answer.
      #: (Hash[String, untyped], WriteUpPointer, AnswerFields, AnswerPlace) -> WriteUpRepoint
      def self.answered(repoint, recorded_at, fields, place)
        new(finding_id: repoint.fetch("finding_id"), recorded_at: recorded_at,
            reason: fields.text_at(repoint["reason"], "repoint.reason", place.child("reason")))
      end

      #: String
      attr_reader :finding_id

      #: (finding_id: String, recorded_at: WriteUpPointer, reason: String) -> void
      def initialize(finding_id:, recorded_at:, reason:)
        @finding_id = finding_id
        @recorded_at = recorded_at
        @reason = reason
        freeze
      end

      # finding moved to this repoint's recorded_at, for its reason, at at.
      #: (RecordedFinding, at: String) -> RecordedFinding
      def applied_to(finding, at:) = finding.moved_to(@recorded_at, at: at, reason: @reason)
    end
  end
end

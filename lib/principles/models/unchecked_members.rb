# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "answer_place"
require_relative "principle_members"
require_relative "refusal_before_shape"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The members of a principle that name no check, whose assessments take no check_result. An answer is read for
    # one before its shape is checked, since the shape would ask for the command such a check_result lacks, sending
    # the agent to fill in what it should remove.
    class UncheckedMembers
      include RefusalBeforeShape

      #: (PrincipleMembers) -> void
      def initialize(members)
        @members = members
        freeze
      end

      # Refuses answer when it gives check_result on the assessment of a member with no check. It reads the answer as
      # sent, so it leaves anything malformed to the shape's refusal or the coverage refusal; source is unused, as
      # other refusals before the shape name it.
      # @override
      #: (untyped, String, Array[Hash[String, String]]) -> void
      def refuse_in(answer, _source, _shape_problems)
        assessments = answer["member_assessments"] if answer.is_a?(Hash)
        return unless assessments.is_a?(Array)

        assessments.each_with_index do |assessment, index|
          next unless stray?(assessment)

          refuse_at(AnswerPlace.member_assessment(index, assessment["member_id"]), assessment["check_result"])
        end
      end

      # Refuses reported, the check_result given on the assessment at place of a member with no check, naming the
      # members that hold the principle's checks, since an agent may have taken this one for one of them; nil
      # when none is given, as such an assessment should.
      #: (AnswerPlace, untyped) -> nil
      def refuse_at(place, reported)
        return unless reported

        raise place.child("check_result").refusal(
          Error.new("invalid_check_result", "the member has no check, so its assessment takes no check_result",
                    ["Remove check_result from this member's assessment.", checked_on].compact.join(" "))
        )
      end

      private

      # The sentence naming the members that hold the principle's checks, or nil when none does.
      #: () -> String?
      def checked_on
        checked = @members.checked_ids
        return if checked.empty?

        "This principle's #{checked.one? ? "check is" : "checks are"} on #{ProseList.new(checked)}."
      end

      # Whether assessment gives a check_result for a mapped member that names no check.
      #: (untyped) -> bool
      def stray?(assessment)
        return false unless assessment.is_a?(Hash) && assessment["check_result"]

        id = assessment["member_id"]
        return false unless id.is_a?(String)

        @members.unchecked?(id)
      end
    end
  end
end

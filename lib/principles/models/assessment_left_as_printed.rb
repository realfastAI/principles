# typed: strict
# frozen_string_literal: true

require_relative "answer_place"
require_relative "left_as_printed"
require_relative "member_assessments"
require_relative "new_findings"
require_relative "recent_decision"
require_relative "refusal_before_shape"
require_relative "sent_prior_decisions"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The judgements a full audit's answer, as sent, leaves as its template printed them: the members', the set's,
    # the recent decision's, a raised finding's text fields and a prior finding's decision. It
    # reads only what it finds in the shape it expects, so it may read an answer whose shape is still to be checked.
    class AssessmentLeftAsPrinted
      include RefusalBeforeShape

      # Refuses answer naming each judgement it leaves as printed, then each of shape_problems elsewhere; nothing
      # when it leaves none. source is unused, as other refusals before the shape name it.
      # @override
      #: (untyped, String, Array[Hash[String, String]]) -> void
      def refuse_in(answer, _source, shape_problems)
        of(answer).refuse(besides: shape_problems) if answer.is_a?(Hash)
      end

      private

      # Each judgement answer leaves as printed, named, with its pointer.
      #: (Hash[String, untyped]) -> LeftAsPrinted
      def of(answer)
        left = members_left(answer["member_assessments"])
        left["collective_assessment"] = "/collective_assessment" if
          answer["collective_assessment"] == AssessmentAnswer::COLLECTIVE_PLACEHOLDER
        left["recent_decision"] = "/recent_decision" if recent_decision_left?(answer["recent_decision"])
        LeftAsPrinted.new(left.merge(listed_left(answer)))
      end

      # Each judgement a member's assessment leaves as printed, named by whose it is and what: its assessment, and an
      # observed delivery's observation.
      #: (untyped) -> Hash[String, String]
      def members_left(assessments)
        return {} unless assessments.is_a?(Array)

        assessments.each_with_index.flat_map do |assessment, index|
          next [] unless assessment.is_a?(Hash)

          place = AnswerPlace.member_assessment(index, assessment["member_id"])
          unwritten_fields(assessment).map { |field| ["#{place.subject} #{field}", place.child(field).pointer] }
        end.to_h
      end

      # The fields of assessment, as sent, that are still the text the template printed there and must be written.
      #: (Hash[String, untyped]) -> Array[String]
      def unwritten_fields(assessment)
        [("assessment" if MemberAssessments::ASSESSMENT.left?(assessment["assessment"])),
         ("observation" if assessment["delivery"] == "observed" &&
                           MemberAssessments::SIGHTING.left?("observation", assessment["observation"]))].compact
      end

      # Each judgement the answer's lists leave as printed: a raised finding's text fields, and a prior finding's
      # decision.
      #: (Hash[String, untyped]) -> Hash[String, String]
      def listed_left(answer)
        findings, decisions = answer.values_at("findings", "prior_finding_decisions")
        { **(NewFindings.new(findings).left_as_printed if findings.is_a?(Array)),
          **(SentPriorDecisions.new(decisions).left_as_printed if decisions.is_a?(Array)) }
      end

      # Whether decision gives fields and leaves each as the template printed it.
      #: (untyped) -> bool
      def recent_decision_left?(decision)
        return false unless decision.is_a?(Hash)

        RecentDecision.new(decision).left_as_printed?
      end
    end
  end
end

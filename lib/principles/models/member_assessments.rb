# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "locator"
require_relative "answer_fields"
require_relative "answer_place"
require_relative "carried_assessments"
require_relative "principle_members"
require_relative "answered_time"
require_relative "member_sighting"
require_relative "misspelt_member_id"
require_relative "named_placeholder"
require_relative "record_judged_against"
require_relative "reported_check"
require_relative "template_placeholders"
require_relative "unchecked_members"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The member_assessments of an assessment answer: one for each mapped member, each with an assessment, a delivery,
    # an observation when delivery is observed, evidence that resolves, and the result of the member's check when it
    # has one.
    class MemberAssessments
      # What a record entry keeps for a member carried forward, until completion puts back its last assessment.
      CARRIED = { "carried_forward" => true }.freeze #: Hash[String, untyped]

      # The text a fresh member's template printed in its assessment before each named its member, which an answer
      # may not send back unchanged, as a correction may not send back its own.
      PLACEHOLDER = "Your assessment, including its context cost" #: String

      # The text a fresh member's template prints in its assessment now, naming the member.
      NAMED_PLACEHOLDER = "Your assessment of #{NamedPlaceholder::SLOT}, including its context cost".freeze #: String

      # The assessment's placeholder, which any member's assessment leaves as printed for any member's id.
      ASSESSMENT = NamedPlaceholder.new(NAMED_PLACEHOLDER, before: PLACEHOLDER) #: NamedPlaceholder

      # The text the template printed alone gives a sighting's fields beside delivery, each left as printed when the
      # delivery gives none.
      SIGHTING = TemplatePlaceholders.new(
        { "observation" => "Only with delivery observed: what you saw the member do, where, and what you did not see",
          "observed_at" => "Only for a sighting before this audit: when, in UTC, or a dated record's date " \
                           "at 00:00:00Z" }
      ) #: TemplatePlaceholders

      # assessments is the answer's member_assessments; members are the mapped members, with each checked one's
      # check; fields checks each field and locates each piece of evidence; judged_against is the principle's record
      # as it stands, which says which members' last assessments may be carried forward, marked {"member_id",
      # "carried_forward": true}, and which command it ran for each member's check; answered_at is when
      # the answer came, which no sighting it reports is after.
      #: (untyped, PrincipleMembers, fields: AnswerFields, answered_at: String, ?judged_against: RecordJudgedAgainst?)
      #|   -> void
      def initialize(assessments, members, fields:, answered_at:, judged_against: nil)
        @sent = assessments #: untyped
        @assessments = given(assessments) #: untyped
        @members = members
        @answered_at = answered_at
        @fields = fields
        @judged_against = judged_against
        @carried = judged_against&.carried #: CarriedAssessments?
        freeze
      end

      # Refuses the assessments unless each mapped member is assessed exactly once, and each assessment is complete.
      #: () -> void
      def check
        assessments = @fields.array(@assessments, "member_assessments")
        refuse_incomplete_coverage(assessments.map { |assessment| assessment["member_id"] })
        assessments.each_with_index { |assessment, index| member_assessment(assessment, place_of(assessment, index)) }
      end

      # The result reported for each checked member's check, by member id, once each has been checked. Call it after
      # check, which refuses an unmapped id first: finding the command the record ran needs each member's key.
      #: () -> Hash[String, Hash[String, untyped]]
      def check_results
        @assessments.each_with_index.to_h do |assessment, index|
          [assessment["member_id"], reported(assessment, place_of(assessment, index))]
        end.compact
      end

      # Each member's assessment by id, as its record entry keeps it: what the agent said, and the hash of each piece
      # of evidence it cited, which the block locates, so the next audit can say whether that evidence changed.
      #: () { (Locator) -> LocatedText } -> Hash[String, Hash[String, untyped]]
      def kept(&locate)
        @assessments.to_h do |assessment|
          next [assessment.fetch("member_id"), { "assessment" => CARRIED }] if carried_forward?(assessment)

          hashes = assessment.fetch("evidence").map { |reference| locate.call(Locator.new(reference)).sha256 }
          [assessment.fetch("member_id"),
           { "assessment" => assessment.slice("assessment", "delivery", "observation", "observed_at", "evidence")
                                       .reject { |key, value| key == "observed_at" && value.nil? }
                                       .merge("evidence_sha256" => hashes) }]
        end
      end

      private

      # assessments without the sighting fields each leaves as printed, which it does not give, each
      # observed_at given with an offset read in audited_at's form.
      #: (untyped) -> untyped
      def given(assessments)
        return assessments unless assessments.is_a?(Array)

        assessments.map { |assessment| assessment.is_a?(Hash) ? in_utc(SIGHTING.given(assessment)) : assessment }
      end

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def in_utc(assessment)
        return assessment unless assessment.key?("observed_at")

        assessment.merge("observed_at" => AnsweredTime.new(assessment["observed_at"]).in_audited_at_form)
      end

      # Refuses answered, the ids the assessments name, unless they are the mapped ids, each once, hinting at any
      # mapped id an unmapped one is spelled like.
      #: (Array[untyped]) -> void
      def refuse_incomplete_coverage(answered)
        ids = @members.ids
        return if answered.sort == ids.sort

        raise Error.new("incomplete_coverage", "Assess each member exactly once: #{ids.join(", ")}",
                        [*(answered - ids).grep(String).filter_map { |id| MisspeltMemberId.new(id).hint(ids) },
                         "Complete the member_assessments array, copying each member id exactly."].join(" "))
      end

      # The place of the assessment at index in the answer, whose fields each refusal about it points into.
      #: (untyped, Integer) -> AnswerPlace
      def place_of(assessment, index) = AnswerPlace.member_assessment(index, assessment["member_id"])

      #: (untyped, AnswerPlace) -> void
      def member_assessment(assessment, place)
        return carried_assessment(assessment, place) if carried_forward?(assessment)

        @fields.text(assessment["assessment"], "member_assessment.assessment")
        sighting = MemberSighting.for(assessment, carried: @carried, answered_at: @answered_at, at: place)
        @fields.evidence(assessment["evidence"], place.child("evidence"))
        sighting.check
        reported(assessment, place)
      end

      # Whether the assessment is a marker carrying forward the member's last one.
      #: (untyped) -> bool
      def carried_forward?(assessment) = assessment.key?("carried_forward")

      # A marker is accepted only for a member the request listed as carried, alone but for its check's result.
      #: (Hash[String, untyped], AnswerPlace) -> void
      def carried_assessment(assessment, place)
        reason = marker_refusal(assessment) or return reported(assessment, place)

        raise Error.new("invalid_answer", "#{assessment["member_id"]} cannot be carried forward: #{reason}",
                        "Assess it as the request's template does, or give only {\"member_id\", " \
                        "\"carried_forward\": true} for a member the request lists with carried_forward.",
                        fields: [{ "pointer" => place.child("carried_forward").pointer, "problem" => reason }])
      end

      # Why a marker cannot carry the member's assessment forward, or nil when it can: the request asks to judge the
      # member, giving why, or the marker is not true or comes with an assessment.
      #: (Hash[String, untyped]) -> String?
      def marker_refusal(assessment)
        return "carried_forward must be true" unless assessment["carried_forward"] == true

        assessed = assessment.keys.intersect?(%w[assessment delivery evidence])
        return "give the marker or an assessment, not both" if assessed

        reason = @carried ? @carried.judge_because(assessment["member_id"]) : "not_assessed_before"
        "the request asks to judge it: judge_because #{reason}" if reason
      end

      # The result reported for the member assessed at place, checked against its check; nil for a member with none,
      # whose assessment UncheckedMembers refuses if it gives one.
      #: (untyped, AnswerPlace) -> Hash[String, untyped]?
      def reported(assessment, place)
        id = assessment["member_id"]
        key = @members.found(id).key
        check = @members.check(id) or return UncheckedMembers.new(@members).refuse_at(place, assessment["check_result"])
        ReportedCheck.new(place, check, ran: @judged_against&.check_run_for(key),
                                        kept: @judged_against&.check_review_for(key) || {})
                     .result(assessment["check_result"])
      end
    end
  end
end

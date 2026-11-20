# typed: strict
# frozen_string_literal: true

require "json"
require "time"
require_relative "../error"
require_relative "answer_place"
require_relative "answer_text"
require_relative "answered_time"
require_relative "carried_assessments"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One member assessment's sighting: whether its delivery was observed, what was seen, and when, as the last full
    # audit's sighting of the member bears on it. Its delivery picks its kind: Observed, or NotObserved.
    class MemberSighting
      # The sighting of assessment, one of the answer's member_assessments at the place at, of the kind its
      # delivery names; carried knows the last full audit's sightings, and answered_at is when the answer came. A
      # delivery other than observed or not_observed is refused here, before the evidence, as the refusals have always
      # come.
      #: (Hash[String, untyped], carried: CarriedAssessments?, answered_at: String, at: AnswerPlace) -> MemberSighting
      def self.for(assessment, carried:, answered_at:, at:)
        case assessment["delivery"]
        when "observed" then Observed.new(assessment, carried: carried, answered_at: answered_at, at: at)
        when "not_observed" then NotObserved.new(assessment, at: at)
        else raise Error.new("invalid_delivery", "Use observed or not_observed",
                             "Record unavailable delivery as not_observed.")
        end
      end

      #: (Hash[String, untyped], at: AnswerPlace) -> void
      def initialize(assessment, at:)
        @assessment = assessment
        @at = at
      end

      # Refuses the sighting unless it holds to its kind's rules.
      #: () -> void
      def check = raise(NotImplementedError, "#{self.class} has no rules of its own")

      private

      #: () -> untyped
      def id = @assessment["member_id"]

      # The JSON pointer to field of this assessment.
      #: (String) -> String
      def pointer(field) = @at.child(field).pointer

      # A delivery not observed has no sighting, so it gives no observed_at.
      class NotObserved < MemberSighting
        #: (Hash[String, untyped], at: AnswerPlace) -> void
        def initialize(assessment, at:)
          super
          freeze
        end

        #: () -> void
        def check
          return unless @assessment.key?("observed_at")

          raise Error.new("invalid_answer", "Member #{id} is not observed but gives observed_at",
                          "Drop observed_at, or record delivery as observed with what you saw in observation.",
                          fields: [{ "pointer" => pointer("observed_at"),
                                     "problem" => "only an observed delivery has a sighting to date" }])
        end
      end

      # An observed delivery says what was seen, and when, as a time the record can compare, and no word-for-word
      # repeat of the last full audit's but as that sighting or one in this audit.
      class Observed < MemberSighting
        SHAPE_EXAMPLE = "2026-11-01T09:30:00Z" #: String
        # A record that gives only its date gives it at midnight UTC, the observation saying the time is unknown.
        DATE_ALONE_EXAMPLE = "2026-11-01T00:00:00Z" #: String
        OR_NULL_FOR_THIS_AUDIT = "or null for a sighting in this audit." #: String
        # The repair for an observed_at naming no UTC time exactly, which shows the form to follow.
        FORM_REPAIR = %(Give "observed_at" like "#{SHAPE_EXAMPLE}", in UTC, #{OR_NULL_FOR_THIS_AUDIT} If the ) +
                      "record gives only a date, give it at 00:00:00Z, such as #{DATE_ALONE_EXAMPLE}, and say in " \
                      "observation that the time is unknown." #: String

        # answered_at is when the answer reporting it came, a UTC time like audited_at, no later than the audit it
        # completes is dated.
        #: (Hash[String, untyped], carried: CarriedAssessments?, answered_at: String, at: AnswerPlace) -> void
        def initialize(assessment, carried:, answered_at:, at:)
          super(assessment, at: at)
          @carried = carried
          @answered_at = answered_at
          freeze
        end

        #: () -> void
        def check
          refuse_missing_observation
          refuse_unshaped_observed_at
          refuse_observed_after_answer
          refuse_repeated_observation
        end

        private

        # An observed delivery needs what was seen: a rule across fields stays in the model.
        #: () -> void
        def refuse_missing_observation
          return if AnswerText.new(@assessment["observation"]).written?

          raise Error.new("invalid_answer", "Member #{id} is observed but has no observation",
                          "Give observation: what you saw the member do, where you saw it, and what you did not see; " \
                          "if you did not see it act, record delivery as not_observed.",
                          fields: [{ "pointer" => pointer("observation"), "problem" => "must be a nonempty string" }])
        end

        # An observed_at is a UTC time in audited_at's form, as the record dates every other sighting, to compare; a
        # date alone or fractional seconds cannot, nor a time no calendar has. One given with an offset arrives
        # here already in that form. Null or none is this audit's.
        #: () -> void
        def refuse_unshaped_observed_at
          observed_at = @assessment["observed_at"]
          return if observed_at.nil? || AnsweredTime.new(observed_at).utc?

          raise Error.new("invalid_answer",
                          "Member #{id}'s observed_at #{observed_at.to_json} is not a UTC time like audited_at",
                          shape_repair(AnsweredTime.new(observed_at)),
                          fields: [{ "pointer" => pointer("observed_at"),
                                     "problem" => "must be a UTC time like #{SHAPE_EXAMPLE}" }])
        end

        # The repair for an observed_at not in audited_at's form: for a date alone, its midnight, to copy, when that is
        # no later than the answer, which would refuse it in turn; otherwise the form to follow.
        #: (AnsweredTime) -> String
        def shape_repair(given)
          exact = given.exact_utc
          return FORM_REPAIR if !given.date_alone? || exact.nil? || AnsweredTime.new(exact).after?(@answered_at)

          %(Give "observed_at" as "#{exact}", that date at 00:00:00Z, and say in observation that the time is ) +
            "unknown, #{OR_NULL_FOR_THIS_AUDIT}"
        end

        # A sighting is made before the answer that reports it, so its observed_at is no later than answered_at.
        # Checked once its form is, so the two compare as times.
        #: () -> void
        def refuse_observed_after_answer
          observed_at = @assessment["observed_at"]
          return if observed_at.nil? || !AnsweredTime.new(observed_at).after?(@answered_at)

          raise Error.new("invalid_answer", "Member #{id}'s observed_at, #{observed_at}, is after this answer",
                          %(Give "observed_at" as when you saw it, no later than #{@answered_at}, ) +
                          OR_NULL_FOR_THIS_AUDIT,
                          fields: [{ "pointer" => pointer("observed_at"),
                                     "problem" => "must not be after this answer, #{@answered_at}" }])
        end

        # A fresh observation that repeats the last full audit's word for word describes that audit's sighting or one
        # made in this audit; only the agent knows which, so it gives the recorded date or null, copied from the repair
        # so it never types a clock time. Any other date is another sighting, described in its own words.
        #: () -> void
        def refuse_repeated_observation
          seen = @carried&.repeated_sighting(id, @assessment["observation"]) or return
          return if @assessment.key?("observed_at") && [seen, nil].include?(@assessment["observed_at"])

          raise Error.new("observation_repeats_last_audit",
                          "#{id}'s observation repeats the last full audit's word for word, a sighting dated #{seen}",
                          %(Give "observed_at": "#{seen}" if you kept that sighting. If you saw the member again, ) +
                          "describe what you saw this time in your own words, with \"observed_at\": null for a " \
                          "sighting in this audit, or the date of another, such as a dated record.",
                          fields: [{ "pointer" => pointer("observed_at"),
                                     "problem" => "must be the last full audit's date or null when observation " \
                                                  "repeats its text" }])
        end
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_place"
require_relative "answer_text"
require_relative "check_result_guide"
require_relative "dated_line"
require_relative "template_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One member's check and the result an agent reports for it. This tool never runs the check: it
    # refuses a report that cannot be about the member's own check, and cannot confirm the run happened.
    class ReportedCheck
      # How review_basis records a review the agent made itself, which the placeholder and the repair both give.
      SELF_REVIEWED = "\"Self-reviewed by the agent: <what you checked it against>\"" #: String
      # The not_run_reason a template prints beside exit_status's placeholder, which an answer that leaves it as
      # printed has not given, so filling exit_status alone reports a run. Short, as the template's rule on
      # fields left as printed says the rest.
      NOT_RUN_PLACEHOLDER = "Only if the check could not run here: why" #: String
      # The review_basis a template prints for a check no audit ran, or one changed since, which an exit_status needs
      # beside it, and which beside not_run_reason left as printed is not given; what to write is the
      # check's instruction.
      REVIEW_BASIS_PLACEHOLDER = "One line: what the review before the run rested on" #: String
      # Why an exit status for a check no audit ran is refused without review_basis, and when given its placeholder.
      NEEDS_BASIS = "check_result needs review_basis beside exit_status, since no audit ran this command" #: String
      LEFT_BASIS = "check_result.review_basis is the template's placeholder, unchanged, and an exit_status for a " \
                   "command no audit ran needs it" #: String
      # The exit_status a template prints where the run's status goes, what to do being the check's instruction.
      EXIT_STATUS_PLACEHOLDER = "the check's exit status, an integer" #: String
      # The placeholder a template prints in each field an answer may leave as printed to give none.
      PLACEHOLDERS = TemplatePlaceholders.new({ "exit_status" => EXIT_STATUS_PLACEHOLDER,
                                                "not_run_reason" => NOT_RUN_PLACEHOLDER,
                                                "review_basis" => REVIEW_BASIS_PLACEHOLDER }) #: TemplatePlaceholders
      # The review_basis a template prints for a check the last audit ran, which left as printed keeps the line that
      # audit kept, and replaced gives a new one.
      KEPT_BASIS_PLACEHOLDER = "Only for a new line on what this run's review rested on; else kept" #: String
      # The placeholders a template prints for a check the last audit ran.
      UNCHANGED_PLACEHOLDERS = TemplatePlaceholders.new(
        { "exit_status" => EXIT_STATUS_PLACEHOLDER, "not_run_reason" => NOT_RUN_PLACEHOLDER,
          "review_basis" => KEPT_BASIS_PLACEHOLDER }
      ) #: TemplatePlaceholders
      BASIS = "Say in review_basis, in one line, what the review before the run rested on, such as " \
              "\"The owner reviewed the command in this session.\" or the document that confirms it. If you did " \
              "the review yourself, such as confirming against the documentation a check you changed, say so: " \
              "#{SELF_REVIEWED}. If no record of the review was " \
              "kept, say so, such as \"Reviewed in an earlier session; basis not kept.\"".freeze #: String

      # assessment is the place of the member's assessment in the answer, whose check_result each refusal points
      # into. ran is the command the principle's stored record was given an exit status for, nil when it ran
      # none; a check it did not run is reviewed before it runs, and the result says in review_basis what that review
      # rested on. kept is the line the stored record keeps for that run's review, with its
      # review_basis_since, which an unchanged check's result carries until the answer gives another. guide is
      # the guidance the request prints, which each repair names.
      #: (AnswerPlace, String, ran: String?, kept: Hash[String, untyped], ?guide: CheckResultGuide) -> void
      def initialize(assessment, check, ran:, kept:, guide: CheckResultGuide::FULL_AUDIT)
        @assessment = assessment
        @check = check
        @ran = ran
        @kept = kept
        @guide = guide
        freeze
      end

      # The reported result, once it is checked against the member's check.
      #: (untyped) -> Hash[String, untyped]
      def result(reported)
        missing_result unless reported
        given = filled(reported)
        same_command(given.fetch("command"))
        unfilled_status(reported, given)
        status_or_reason(given)
        review_basis(given, left: placeholders.left?("review_basis", reported["review_basis"]))
        carrying_review(given)
      end

      private

      # The fields reported gives, leaving out those the template left as printed: an exit_status still the
      # placeholder string that says how to run the check, and each field as its placeholder; and a null
      # not_run_reason, or a null review_basis but for an unchanged check's, whose null drops its kept line.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def filled(reported)
        placeholders.given(reported).reject do |field, value|
          (field == "exit_status" && value.is_a?(String)) ||
            (value.nil? && (field == "not_run_reason" || (field == "review_basis" && @ran != @check)))
        end
      end

      # The placeholders the template printed for this check: for one the stored record ran, a review_basis that
      # left as printed keeps its line; for any other, one an exit_status needs replaced.
      #: () -> TemplatePlaceholders
      def placeholders = @ran == @check ? UNCHANGED_PLACEHOLDERS : PLACEHOLDERS

      # The place of the reported check_result, or of one of its fields.
      #: (?String?) -> AnswerPlace
      def reported_at(field = nil)
        place = @assessment.child("check_result")
        field ? place.child(field) : place
      end

      # Refuses an assessment of a checked member that reports no result for its check, pointing at the assessment
      # it is missing from.
      #: () -> bot
      def missing_result
        refuse(@assessment, "the member has a check, which context.members gives, so its assessment needs a " \
                            "check_result", @guide.missing)
      end

      #: (String) -> void
      def same_command(command)
        return if command == @check

        refuse(reported_at("command"), "check_result.command is not the member's check as context.members gives it",
               @guide.command)
      end

      # Refuses a result that gives neither field but text in exit_status: the template's placeholder, or other text
      # written where only the status goes, so the repair says what replaces it.
      #: (Hash[String, untyped], Hash[String, untyped]) -> void
      def unfilled_status(reported, given)
        return if given.key?("exit_status") || given.key?("not_run_reason") || !reported["exit_status"].is_a?(String)

        refuse(reported_at("exit_status"), "check_result.exit_status is text, not the command's exit status",
               "Replace exit_status, which the template prints as text to replace, with the exit status as an " \
               "integer once the command has run, or write why it could not run in not_run_reason.")
      end

      #: (Hash[String, untyped]) -> void
      def status_or_reason(reported)
        unless reported.key?("exit_status") ^ reported.key?("not_run_reason")
          refuse(reported_at, "check_result needs exactly one of exit_status and not_run_reason",
                 @guide.status_or_reason)
        end
        return if !reported.key?("not_run_reason") || AnswerText.new(reported["not_run_reason"]).written?

        refuse(reported_at("not_run_reason"), "check_result.not_run_reason must be a nonempty string",
               "Say why the command could not be run here.")
      end

      # Refuses an exit status for a check the stored record did not run unless review_basis says what its review
      # rested on, and any review_basis that is not one written line. What the line says is the agent's: this tool
      # keeps it and cannot verify it. left says the template's placeholder was sent back in it, which the refusal
      # names.
      #: (Hash[String, untyped], left: bool) -> void
      def review_basis(reported, left:)
        if reported.key?("review_basis")
          return if reported["review_basis"].nil? || AnswerText.new(reported["review_basis"]).one_line?

          refuse(reported_at("review_basis"), "check_result.review_basis is not one written line", BASIS)
        end
        return unless reported.key?("exit_status") && @ran != @check

        refuse(reported_at("review_basis"), left ? LEFT_BASIS : NEEDS_BASIS, BASIS)
      end

      # The result as the record keeps it: an unchanged check's exit status with the kept line and its date when the
      # answer gives the same line or none, or the answer's new line alone; an unchanged check not run without the
      # kept line, which its template prints; any other result as reported.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def carrying_review(reported)
        return reported unless @ran == @check
        return reported.reject { |field, line| field == "review_basis" && line == @kept["review_basis"] } \
          unless reported.key?("exit_status")

        line = DatedLine.new(reported.fetch("review_basis", @kept["review_basis"]), field: "review_basis")
        reported.except("review_basis").merge(line.kept_over(@kept))
      end

      # Refuses with what is wrong at place, which the refusal names with whose it is and points at.
      #: (AnswerPlace, String, String) -> bot
      def refuse(place, message, repair)
        raise place.refusal(Error.new("invalid_check_result", message, repair))
      end
    end
  end
end

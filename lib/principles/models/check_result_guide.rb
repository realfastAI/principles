# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The guidance a request prints for reporting a member's check, which ReportedCheck's repairs name, so a repair
    # sends the agent only to text its own request holds: a full audit's answer_guide, or what another request prints
    # in its place.
    class CheckResultGuide
      # What to merge a check_result from, in a full audit's request.
      SHAPES = "Merge one inner example from answer_guide.check_result.examples into that member's " \
               "response_template.check_result as copy_from says."

      # How to report a check_result that gives none, the wrong command, or not exactly one of exit_status and
      # not_run_reason.
      #: String
      attr_reader :missing, :command, :status_or_reason

      #: (missing: String, command: String, status_or_reason: String) -> void
      def initialize(missing:, command:, status_or_reason:)
        @missing = missing
        @command = command
        @status_or_reason = status_or_reason
        freeze
      end

      # The guidance a full audit's request prints: context.members and answer_guide.check_result.
      FULL_AUDIT = new(
        missing: "Report the member's check once you have run it, after a review if " \
                 "answer_guide.check_result.limits asks for one. #{SHAPES}",
        command: "Report the command exactly as context.members lists it, run after a review if " \
                 "answer_guide.check_result.limits asks for one.",
        status_or_reason: "Give exit_status once the command has run, or not_run_reason if it could not, " \
                          "including when no review it needed was possible. #{SHAPES}"
      ) #: CheckResultGuide

      # The guidance a one-member, several-member or across-principles acknowledgement prints instead: the member's
      # check under member.check, its check_instruction and the template's exit_status slot, with no answer_guide.
      ACKNOWLEDGEMENT = new(
        missing: (run_and_report = "Run the member's check as its check_instruction in the request's context says, " \
                                   "then give its exit status under check_result.exit_status, as the template " \
                                   "prints it."),
        command: "Leave check_result.command out, or give the member's check exactly as the request's context " \
                 "prints it under member.check.",
        status_or_reason: run_and_report
      ) #: CheckResultGuide
    end
  end
end

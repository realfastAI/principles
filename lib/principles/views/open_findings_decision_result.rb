# typed: strict
# frozen_string_literal: true

require_relative "answer_in_a_file"
require_relative "invocation"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A decision on a principle's open findings between full audits: its request and its result.
    class OpenFindingsDecisionResult
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The request for a decision on any of findings, the open findings, each with its recorded_at and what
      # list-open-findings says of its write-up, whose template names each finding alone, so one left as printed
      # changes nothing, under fields, each field a decision may give with its meaning, printed at its head.
      #: (request_id: String, principle_id: String, revision: String?, findings: Array[Hash[String, untyped]],
      #|  fields: Hash[String, String]) -> Hash[String, untyped]
      def decision_request(request_id:, principle_id:, revision:, findings:, fields:)
        decisions = findings.map { |finding| { "finding_id" => finding["finding_id"] } }
        { "status" => "agent_judgement_required", "request_id" => request_id, "phase" => "deciding",
          "context" => { "principle_id" => principle_id, "findings" => findings,
                         "question" => Prompts.text("decide-open-findings/give-only-what-changed-of-each") },
          "response_template" => { "request_id" => request_id, "basis" => { "revision" => revision },
                                   "decision_fields" => fields, "decisions" => decisions },
          "answer_with" => @invocation.submit_answer(request_id),
          "next_action" => AnswerInAFile.new(@invocation).open_findings(principle_id, request_id:) }
      end

      # The decisions were accepted, changing the findings changed names, and file holds them; not_found_elsewhere
      # is each other principle's open finding whose write-up cannot be found, as its principle and finding_id (T16).
      #: (principle_id: String, file: String, changed: Array[String], not_found_elsewhere: Array[Hash[String, String]])
      #|  -> Hash[String, untyped]
      def decided(principle_id:, file:, changed:, not_found_elsewhere:)
        { "status" => "open_findings_decided", "principle_id" => principle_id, "changed" => changed,
          "other_write_ups_not_found" => not_found_elsewhere, "files_to_commit" => [file],
          "next_action" => "Commit #{file}. Then check each change as the session-start line will state it: " \
                           "#{@invocation.in_project("list-open-findings", principle_id, usage: "--lines")}" \
                           "#{elsewhere(not_found_elsewhere.map { it.fetch("principle") }.uniq)}" }
      end

      private

      # The request that decides each other principle's open findings, one per line, or nothing when there is none.
      #: (Array[String]) -> String
      def elsewhere(principle_ids)
        return "" if principle_ids.empty?

        commands = principle_ids.map { |id| "#{@invocation.in_project("start-audit", id, usage: "--open-findings")}\n" }
        "\nWrite-ups of other principles cannot be found either, listed under other_write_ups_not_found. " \
          "Check each, and point it at its write-up with its own request:\n#{commands.join}"
      end
    end
  end
end

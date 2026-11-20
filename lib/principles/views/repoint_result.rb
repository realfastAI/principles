# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A repoint of a principle's open findings' write-ups: its request and its result.
    class RepointResult
      # What an accepted repoint did: the ids of the findings it repointed and of those it left where they point,
      # and each other principle's open finding whose write-up cannot be found, with those principles (T16).
      class Outcome
        #: Array[String]
        attr_reader :repointed, :unchanged
        # Each as its principle and finding_id.
        #: Array[Hash[String, String]]
        attr_reader :not_found_elsewhere

        #: (repointed: Array[String], unchanged: Array[String], not_found_elsewhere: Array[Hash[String, String]])
        #|  -> void
        def initialize(repointed:, unchanged:, not_found_elsewhere:)
          @repointed = repointed
          @unchanged = unchanged
          @not_found_elsewhere = not_found_elsewhere
          freeze
        end

        # The other principles not_found_elsewhere names, each once.
        #: () -> Array[String]
        def principles_elsewhere = @not_found_elsewhere.map { |finding| finding.fetch("principle") }.uniq
      end

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # findings are the open findings, each with its recorded_at and what list-open-findings says of its write-up.
      #: (request_id: String, principle_id: String, revision: String?, findings: Array[Hash[String, untyped]])
      #|  -> Hash[String, untyped]
      def request(request_id:, principle_id:, revision:, findings:)
        repoints = findings.map do |finding|
          { "finding_id" => finding["finding_id"], "recorded_at" => nil, "reason" => "" }
        end
        { "status" => "agent_judgement_required", "request_id" => request_id, "phase" => "repointing",
          "context" => { "principle_id" => principle_id, "findings" => findings,
                         "question" => Prompts.text("repoint-write-ups/point-each-moved-write-up-at-its-new-place") },
          "response_template" => { "request_id" => request_id, "basis" => { "revision" => revision },
                                   "repoints" => repoints },
          "answer_with" => @invocation.submit_answer(request_id) }
      end

      # The repoints were accepted, as outcome says, and file holds them.
      #: (principle_id: String, file: String, outcome: Outcome) -> Hash[String, untyped]
      def repointed(principle_id:, file:, outcome:)
        { "status" => "write_ups_repointed", "principle_id" => principle_id, "repointed" => outcome.repointed,
          "unchanged" => outcome.unchanged, "other_write_ups_not_found" => outcome.not_found_elsewhere,
          "files_to_commit" => [file],
          "next_action" => "Commit #{file}. After committing, this names no write-up of #{principle_id} it cannot " \
                           "find: #{@invocation.in_project("list-open-findings", principle_id, usage: "--short")}" \
                           "#{elsewhere(outcome.principles_elsewhere)}" }
      end

      private

      # The request that repoints each other principle's write-ups, one per line, or nothing when there is none.
      #: (Array[String]) -> String
      def elsewhere(principle_ids)
        return "" if principle_ids.empty?

        commands = principle_ids.map { |id| "#{@invocation.in_project("start-audit", id, usage: "--write-ups")}\n" }
        "\nWrite-ups of other principles cannot be found either, listed under other_write_ups_not_found. " \
          "Check each, and repoint it with its own request:\n#{commands.join}"
      end
    end
  end
end

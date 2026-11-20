# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/finding_write_ups"
require_relative "../models/request_id"
require_relative "../models/submitted_answer"
require_relative "acknowledgement"
require_relative "acknowledgements"
require_relative "correction"
require_relative "repoint"
require_relative "assessment"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # Answering an audit's requests: this tool checks the answer against the project's files and, when the
    # audit completes, writes the committed audit record. Nothing else is stored: each request id is a
    # digest of what the request depends on, so an answer is checked against the project as it is now.
    class Answer < Command
      # The controller that answers for each phase a request id may name.
      PHASE_CONTROLLERS = {
        "assessment" => Assessment, "correction" => Correction, "acknowledgement" => Acknowledgement,
        "acknowledgements" => Acknowledgements, "repointing" => Repoint
      }.freeze #: Hash[String, Class[AnswerPhase]]

      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          case command
          when "submit-answer" then submit_answer(submitted(options))
          when "show-answer-check"
            next correction_to_fill(submitted(options)) if options["as"]

            check_answer(submitted(options), options.fetch("file"))
          else unknown(command)
          end
        end
      end

      private

      # The answer from --file, where - means it was read from stdin, to the request REQUEST_ID names, or the answer's
      # own request_id when none is given, checked against the schema for the phase that id names once its head
      # says it answers a request that still matches the project, with the prior findings a full audit's request
      # listed, which checking its head found.
      #: (Hash[String, untyped]) -> Models::SubmittedAnswer
      def submitted(options)
        sent = @project.answer(options.fetch("file"), stdin: options["stdin"], given: options["request_id"])
        request_id = sent.request_id
        prior = checked_head(request_id, sent.head)
        Models::SubmittedAnswer.new(request_id, sent.checked(phase(request_id).before_shape(request_id)), prior)
      end

      # Refuses an answer from its head alone: a record a later copy wrote is refused first, read afresh as
      # start-audit reads it, so nothing is written over one that landed mid-audit, then an answer to another
      # request, then whatever the phase checks of its request from the head alone.
      #: (Models::RequestId, Hash[String, untyped]) -> Models::PriorFindings?
      def checked_head(request_id, head)
        @audit_records.refuse_newer(request_id.principle_id, version: @tool.version)
        request_id.check_answer(head)
        phase(request_id).checked_request(request_id, head)
      end

      # Accepts the answer and writes the record changes it makes.
      #: (Models::SubmittedAnswer) -> untyped
      def submit_answer(submitted)
        output, changes = judged(submitted)
        carried = phase(submitted.request_id).carried_naming_decided(submitted)
        wrote = changes.map { |record| @audit_records.save(record) }
        presented = audit_result.present(output)
        audit_result.submitted_citing_decided_findings(presented, carried, submitted.request_id.principle_id)
                    .merge("wrote" => wrote)
      end

      # Runs every check submit-answer would, says what it would write and each fact to confirm first, such as a
      # write-up pointer it drops, writing nothing; its submit command gives answer_file, the --file value it was
      # checked from, again. An assessment with findings also gives the
      # correction's answer it leads to, to fill.
      #: (Models::SubmittedAnswer, String) -> untyped
      def check_answer(submitted, answer_file)
        output, changes = judged(submitted)
        checked = to_confirm(acceptable(submitted, answer_file, changes), submitted, changes)
        audit_result.with_correction_to_fill(checked, output, answer_file: answer_file).merge("wrote" => [])
      end

      # The acceptable result with each fact to confirm before submitting named first in its next_action: a carried
      # assessment citing a decided finding, a write-up pointer the answer drops, and a deferral the record changes
      # write up nowhere.
      #: (Hash[String, untyped], Models::SubmittedAnswer, Array[Models::AuditRecord]) -> Hash[String, untyped]
      def to_confirm(acceptable, submitted, changes)
        answering = phase(submitted.request_id)
        checked = audit_result.citing_decided_findings(acceptable, answering.carried_naming_decided(submitted))
        checked = audit_result.dropping_pointers(checked, answering.pointers_dropped(submitted))
        audit_result.deferred_written_up_nowhere(checked, answering.deferred_written_up_nowhere(changes))
      end

      # The correction's answer an assessment with findings leads to, alone, as show-answer-check --as template prints
      # it to fill; refused for any other answer, which leads to none. Writes nothing.
      #: (Models::SubmittedAnswer) -> Hash[String, untyped]
      def correction_to_fill(submitted)
        output, = judged(submitted)
        output.correction_to_fill or
          raise Error.new("no_correction_to_fill",
                          "This answer to #{submitted.request_id} leads to no correction: --as template prints the " \
                          "correction's answer that an assessment with findings leads to.",
                          "Check it without --as template, which says what submitting it would write.")
      end

      # The answer passed every check: what submitting it would write, and its submit command.
      #: (Models::SubmittedAnswer, String, Array[Models::AuditRecord]) -> Hash[String, untyped]
      def acceptable(submitted, answer_file, changes)
        written_up = Models::FindingWriteUps.of(@project, changes).written_up
        # Only a correction's fixed dispositions claim map entries; for any other answer this is empty, read from
        # no map, and left out.
        audit_result.acceptable(submitted.request_id.to_s,
                                changes.map { |record| @audit_records.file(record.principle_id) },
                                answer_file:, open_findings_will_print: (written_up unless written_up.empty?),
                                map_entry_changes: claimed_map_entry_changes(submitted))
      end

      # What each map entry a fix in the answer claims changed, which only a correction's fixes claim.
      #: (Models::SubmittedAnswer) -> Array[Hash[String, untyped]]
      def claimed_map_entry_changes(submitted) = phase(submitted.request_id).map_entry_changes(submitted)

      # The result of answering, and each record change the answer makes, not yet written.
      #: (Models::SubmittedAnswer) -> [untyped, Array[Models::AuditRecord]]
      def judged(submitted) = phase(submitted.request_id).answered(submitted)

      # The controller of the phase request_id names, which answers for it.
      #: (Models::RequestId) -> AnswerPhase
      def phase(request_id) = handed(PHASE_CONTROLLERS.fetch(request_id.phase))
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "assessment_request"
require_relative "answer_in_a_file"
require_relative "answered_request"
require_relative "audit_changes"
require_relative "completed_audit_next_step"
require_relative "correction_request"
require_relative "invocation"
require_relative "prior_finding_decisions_result"
require_relative "prompts"
require_relative "report_hooks_offer"
require_relative "shell_word"
require_relative "trimmed_instructions_note"
require_relative "../prose_list"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The JSON result of an audit command. Printed commands name the executable and project that are
    # running now, so they are added here each time: a request stays answerable after a move or reinstall
    # (alpha 008 friction 16). A completed result names the files to commit and how to show the record,
    # not what the agent has just written (alpha 008 friction 14, alpha 009 friction 3, alpha 010
    # friction 2).
    class AuditResult
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # An answer's result as submit-answer prints it: a correction request in full, with how to answer it.
      #: (AnsweredRequest | CorrectionRequest) -> Hash[String, untyped]
      def present(output) = output.presented_with(self)

      # A correction request adds its answer to fill; a terminal result leaves the acceptable preview alone.
      #: (Hash[String, untyped], AnsweredRequest | CorrectionRequest, answer_file: String) -> Hash[String, untyped]
      def with_correction_to_fill(acceptable, output, answer_file:)
        output.with_correction_to_fill(acceptable, @invocation, answer_file)
      end

      # show-answer-check: the answer passed every check, and what submitting it would write. open_findings_will_print
      # previews each written-up finding's write_up_opening, and is nil when the record would keep none.
      # map_entry_changes gives each claimed map entry's changed role and check, left out when there is none.
      # answer_file is the --file value the answer was checked from, which the submit command gives again.
      #: (String, Array[String], answer_file: String, ?open_findings_will_print: Array[Hash[String, untyped]]?,
      #|  ?map_entry_changes: Array[Hash[String, untyped]]) -> Hash[String, untyped]
      def acceptable(request_id, would_write, answer_file:, open_findings_will_print: nil, map_entry_changes: [])
        submit = @invocation.submit_answer(request_id, file: answer_file)
        waits = "Submitting this answer writes nothing: the audit record already holds what it would write.\n"
        waits = "" unless would_write.empty?
        result = { "status" => "answer_acceptable", "request_id" => request_id, "would_write" => would_write }
        result = result.merge("open_findings_will_print" => open_findings_will_print) if open_findings_will_print
        result = result.merge("map_entry_changes" => map_entry_changes) unless map_entry_changes.empty?
        result.merge("next_action" => "#{waits}Submit the same answer unchanged, as you gave it: #{submit}")
      end

      # show-answer-check's acceptable result, with each carried member whose kept assessment names a finding the
      # answer decides other than still_holds under carried_assessments_citing_decided_findings, and a first line
      # asking the agent to judge each; unchanged when there is none.
      #: (Hash[String, untyped], Array[Hash[String, untyped]]) -> Hash[String, untyped]
      def citing_decided_findings(acceptable, carried)
        judged_first(acceptable, "carried_assessments_citing_decided_findings", carried,
                     Prompts.text("assess-every-member/judge-a-carried-assessment-citing-a-decided-finding"))
      end

      # show-answer-check's acceptable result, with each prior finding whose write-up pointer the answer drops with
      # null, and the pointer it had, under prior_findings_pointers_dropped, and a first line asking the agent to
      # confirm each; unchanged when there is none.
      #: (Hash[String, untyped], Array[Hash[String, untyped]]) -> Hash[String, untyped]
      def dropping_pointers(acceptable, dropped)
        judged_first(acceptable, "prior_findings_pointers_dropped", dropped,
                     Prompts.text("assess-every-member/confirm-each-write-up-pointer-the-answer-drops"))
      end

      # show-answer-check's acceptable result, its first line naming each deferred finding the answer writes up nowhere
      # and saying that null is allowed; unchanged when there is none.
      #: (Hash[String, untyped], Array[String]) -> Hash[String, untyped]
      def deferred_written_up_nowhere(acceptable, finding_ids)
        return acceptable if finding_ids.empty?

        line = Prompts.text("dispose-of-each-finding/confirm-each-deferral-written-up-nowhere",
                            finding_ids: ProseList.new(finding_ids).to_s)
        acceptable.merge("next_action" => "#{line}\n#{acceptable.fetch("next_action")}")
      end

      # submit-answer's result for principle_id's assessment, as citing_decided_findings gives show-answer-check's,
      # its first line saying, since the answer is now written, that the next full audit judges each afresh.
      #: (Hash[String, untyped], Array[Hash[String, untyped]], String) -> Hash[String, untyped]
      def submitted_citing_decided_findings(result, carried, principle_id)
        judged_first(result, "carried_assessments_citing_decided_findings", carried,
                     Prompts.text("assess-every-member/judge-a-submitted-carried-assessment-citing-a-decided-finding",
                                  start_audit: @invocation.in_project("start-audit", principle_id)))
      end

      # start-audit: the assessment request, as a judgement to answer under its request id, its context naming the
      # instructions it prints only in part and the flag that prints one whole, so a trimmed field is not taken for
      # the whole, without the command the agent just ran, after its head, which sizes each part as part_bytes.
      #: (AssessmentRequest, part_bytes: Hash[String, Integer]) -> Hash[String, untyped]
      def assessment_request(request, part_bytes:)
        output = judgement("assessment", request, assessment_head(request.principle_id, part_bytes),
                           to_fill: { "response_template" => request.template })
        note = TrimmedInstructionsNote.new(request.trimmed_instruction_fields).to_h
        fill = AnswerInAFile.new(@invocation).assessment(request.principle_id, request_id: request.request_id)
        output.merge("context" => output.fetch("context").merge(note), "next_action" => fill)
      end

      # start-audit --as template: the assessment's answer alone, to fill and submit.
      #: (AssessmentRequest) -> Hash[String, untyped]
      def answer_to_fill(request) = request.template_to_fill

      # submit-answer: the correction request that follows an assessment with findings, as a judgement to answer
      # under its request id, saying what submitting the assessment stored and how to fill its answer by hand. Its
      # answer to fill is left to show-open-correction, which next_action says to save it from, rather than printed
      # here too.
      #: (CorrectionRequest) -> Hash[String, untyped]
      def correction_request(request)
        judgement("correction", request).merge("stored" => request.stored,
                                               "correction_recovery" => request.recovery(@invocation),
                                               "next_action" => request.to_fill_by_hand(@invocation))
      end

      # A completed audit: its resolved and open findings, the files to commit and, in git, each changed
      # member's commits since the base commit and the command that commits those files alone, each prior
      # finding's decision, and the next step. The command's subject states only what the audit did, which the
      # agent rewords to its project's convention.
      #: (principle_id: String, resolved: Array[untyped], open: Array[untyped], changes: AuditChanges,
      #|  decisions: PriorFindingDecisionsResult) -> Hash[String, untyped]
      def completion(principle_id:, resolved:, open:, changes:, decisions:)
        changed = changes.to_h
        commit = changes.commit("Audit #{principle_id}: #{resolved.length} resolved, #{open.length} open",
                                @invocation.project)
        output = { "status" => "audit_completed", "principle_id" => principle_id, "resolved_findings" => resolved,
                   "open_findings" => open, "files_to_commit" => changes.files_to_commit,
                   "limits" => Prompts.text("report-the-completed-audit/what-completion-means"),
                   **changed.except("files_to_commit"), **commit.fields }
        next_action = CompletedAuditNextStep.new(@invocation).to_s(principle_id, changes, commit)
        decisions.added_to(output).merge("next_action" => next_action,
                                         "full_record" => @invocation.in_project("show-audit", principle_id))
      end

      # completed, a completed audit's result, offering to set principles up after its next_action, as it does
      # while nothing keeps them held between audits, and with hooks, the hook entries that report between them.
      #: (Hash[String, untyped], hooks: bool) -> Hash[String, untyped]
      def offering_set_up(completed, hooks:)
        offers = [Prompts.text("set-principles-up/keep-them-held-between-audits",
                               command: @invocation.in_project("show-meta-principle-passage"))]
        offers << ReportHooksOffer.new(@invocation).to_s if hooks
        completed.merge("next_action" => [completed.fetch("next_action"), *offers].join("\n"))
      end

      # The notice start-audit adds when the last audit's record is not committed.
      #: (String) -> String
      def uncommitted_record_notice(file)
        "The last audit's record, #{file}, is not committed. Commit it, so the project keeps it."
      end

      # The notice start-audit adds, in git, when the last audit's record is open: its correction completes it, so it
      # is never committed.
      #: (String) -> String
      def open_record_notice(file)
        "The last audit's record, #{file}, holds an open audit, waiting on its correction. Do not commit it: submit " \
          "that correction, or answer this request, which replaces it, or discard it with `git restore #{file}`."
      end

      # Wraps a known judgement request with this run's project and answer command.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def request(output)
        submit = @invocation.submit_answer(output.fetch("request_id"))
        output.merge("project" => @invocation.project, "answer_with" => submit)
      end

      private

      # result with facts under field and judge as next_action's first line, or all of it for a request to answer,
      # which has none; unchanged when facts is empty.
      #: (Hash[String, untyped], String, Array[Hash[String, untyped]], String) -> Hash[String, untyped]
      def judged_first(result, field, facts, judge)
        return result if facts.empty?

        result.merge(field => facts, "next_action" => [judge, result["next_action"]].compact.join("\n"))
      end

      # What a full audit's request of principle_id prints before its context: the command listing its parts, so a
      # long request is read in parts rather than paged by script, and part_bytes, each part's bytes by its name as a
      # shell reads it, as the index prints them, so the agent sizes its reads without running a script for them.
      #: (String, Hash[String, Integer]) -> Hash[String, untyped]
      def assessment_head(principle_id, part_bytes)
        { "read_in_parts" => read_in_parts(principle_id),
          "part_bytes" => part_bytes.transform_keys { ShellWord.new(it).to_s } }
      end

      # How to read principle_id's full-audit request in parts: the command listing them, and the flag printing one.
      #: (String) -> String
      def read_in_parts(principle_id)
        index = @invocation.in_project("start-audit", principle_id, options: ["--part", ContextParts::INDEX])
        Prompts.text("assess-every-member/read-the-request-in-parts", index:)
      end

      # request as a judgement to answer in phase, under its id, which its template's head also gives, with any
      # opening fields after the phase and before the context, and to_fill, the answer to fill when this request
      # prints it, after the context.
      #: (String, AssessmentRequest | CorrectionRequest, ?Hash[String, untyped], ?to_fill: Hash[String, untyped])
      #|  -> Hash[String, untyped]
      def judgement(phase, request, opening = {}, to_fill: {})
        { "status" => "agent_judgement_required", "request_id" => request.request_id, "phase" => phase, **opening,
          "context" => request.context, **to_fill,
          "limits" => Prompts.text("answer-any-judgement-request/what-a-self-audit-cannot-show") }
      end
    end
  end
end

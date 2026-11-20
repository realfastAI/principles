# typed: strict
# frozen_string_literal: true

require_relative "answer_head"
require_relative "invocation"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The correction request that follows an assessment with findings: one disposition for each, with a guide to
    # every disposition's shape, and what submitting the assessment stored.
    class CorrectionRequest
      # head is what the answer hands back unchanged, the request's id and the basis the correction depends on;
      # placeholders is the text the template leaves in each field the agent writes.
      #: (head: AnswerHead, principle_id: String, findings: Array[untyped], placeholders: Hash[String, String]) -> void
      def initialize(head:, principle_id:, findings:, placeholders:)
        @head = head
        @principle_id = principle_id
        @findings = findings
        @placeholders = placeholders
        freeze
      end

      # The id the request is answered under.
      #: () -> String
      def request_id = @head.request_id

      # The findings to dispose of, the question and a guide to every disposition's shape.
      #: () -> Hash[String, untyped]
      def context
        { "principle_id" => @principle_id, "findings" => @findings,
          "question" => Prompts.text("dispose-of-each-finding/fix-or-record-each-finding"),
          "answer_guide" => Prompts.data("dispose-of-each-finding/answer-guide") }
      end

      # The answer to fill in, as show-open-correction and show-answer-check --as template print it alone: one
      # disposition for each finding, each action the placeholder that says what it may be and what each adds, so
      # both print one template.
      #: () -> Hash[String, untyped]
      def template
        @head.leading("dispositions" => @findings.map do |finding|
          { "finding_id" => finding["id"], "action" => @placeholders.fetch("action"),
            "reason" => @placeholders.fetch("reason"), "changed_members" => [], "removed_members" => [],
            "evidence" => [],
            "reassessment" => @placeholders.fetch("reassessment"), "recorded_at" => nil, "waits_on" => nil }
        end)
      end

      # The correction's answer alone, as show-answer-check --as template prints it.
      #: () -> Hash[String, untyped]
      def correction_to_fill = template

      #: (AuditResult) -> Hash[String, untyped]
      def presented_with(view)
        view.request(view.correction_request(self))
      end

      # How to save and fill the correction's answer after submitting the checked assessment, naming the command that
      # prints it alone rather than printing it here; keep its submit last.
      #: (Hash[String, untyped], Invocation, String) -> Hash[String, untyped]
      def with_correction_to_fill(acceptable, invocation, answer_file)
        assessment_id = acceptable.fetch("request_id")
        save = "Once this answer is submitted with the last line's command, save the correction's answer it leads " \
               "to in a file outside the project, such as under $TMPDIR, from this command's output: " \
               "#{alone(assessment_id, answer_file, invocation)}\nFill only its dispositions, and submit it: " \
               "#{invocation.submit_answer(request_id)}"
        acceptable.merge("correction_recovery" => recovery(invocation),
                         "next_action" => "#{save}\n#{acceptable.fetch("next_action")}")
      end

      # How to fill the correction by hand: save its answer alone, which show-open-correction prints from the open
      # record, to a file, fill only its dispositions there, and submit that file.
      #: (Invocation) -> String
      def to_fill_by_hand(invocation)
        "Save the correction's answer alone in a file outside the project, such as under $TMPDIR, from this " \
          "command's output, which prints it again from the open record whenever you need it: " \
          "#{invocation.in_project("show-open-correction", @principle_id)}\nEdit only its dispositions in that " \
          "file, then submit it: #{invocation.submit_answer(request_id)}"
      end

      # What to keep while the correction is open, and the read-only command that prints its answer again from the
      # open record, in git or outside it.
      #: (Invocation) -> String
      def recovery(invocation)
        "#{Prompts.text("dispose-of-each-finding/retain-assessment-and-correction")}\n" \
          "#{invocation.in_project("show-open-correction", @principle_id)}"
      end

      # The read-only command that prints the correction's answer alone, checking the assessment request
      # assessment_request_id from assessment_file again.
      #: (String, String, Invocation) -> String
      def alone(assessment_request_id, assessment_file, invocation)
        invocation.in_project("show-answer-check", assessment_request_id,
                              options: ["--file", assessment_file, "--as", "template"])
      end

      # What submitting the assessment stored, and what submitting it again would do, so an assessment submitted
      # twice plainly replaced nothing: the open record, which keeps the assessment and, outside git, what the audit
      # began from, and which in git is never committed, since the correction completes it.
      #: () -> String
      def stored
        kept = "This audit's open record, listed under wrote when it was first written, keeps your assessment"
        again = "Submitting the same assessment again prints this same request and leaves that record as it is."
        return "#{kept} and what the audit began from. #{again}" unless @head.based_on_a_commit?

        "#{kept} until this correction completes the audit; do not commit it. #{again}"
      end
    end
  end
end

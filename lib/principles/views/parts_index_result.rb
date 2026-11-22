# typed: strict
# frozen_string_literal: true

require_relative "assessment_request"
require_relative "context_parts"
require_relative "invocation"
require_relative "answer_in_a_file"
require_relative "shell_word"
require_relative "trimmed_instructions_note"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # start-audit --part index: a full audit's parts with how to answer the request from them, so an agent reading the
    # request in parts need not read it whole to learn how to answer it.
    class PartsIndexResult
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The index of request, with the note naming the instructions it prints only in part, the command that submits
      # its answer and, as the next step, reading each part, where skipping a carried member's is the agent's choice,
      # then filling the answer the template part prints bare, which is too large to carry here, keeping each carried
      # entry, in a file the agent edits with its own tool, since escaping prose for a shell took a script.
      #: (Hash[String, untyped], AssessmentRequest) -> Hash[String, untyped]
      def printed(index, request)
        request_id = index.fetch("request_id")
        read = "Run part_command with each part as printed; skipping a member marked carries_forward is fine, " \
               "unless you judge it again. --as template prints the same answer long, with each slot's help. " \
               "Then fill in the answer the response_template part prints"
        fill = AnswerInAFile.new(@invocation).assessment(request.principle_id, request_id:)
        listed(index, request.principle_id)
          .merge(TrimmedInstructionsNote.new(request.trimmed_instruction_fields).to_h)
          .merge("answer_with" => @invocation.submit_answer(request_id),
                 "next_action" => "#{read}, #{carried(request)}. #{fill}")
      end

      private

      # How to fill each carried member's entry: as printed, but for any check_result slot one prints.
      #: (AssessmentRequest) -> String
      def carried(request)
        kept = "leaving each carries_forward entry as printed"
        request.carried_check_to_fill? ? "#{kept} but for filling the check_result slot it prints" : kept
      end

      # The index under its request id, after the command that prints a part named after it, each entry's part as a
      # shell reads it, quoted where a shell would split or expand it, so it runs as printed; the answer's template
      # names each member by its id unquoted. One command rather than one an entry, since an entry's would repeat it
      # and cost more than reading the whole request.
      #: (Hash[String, untyped], String) -> Hash[String, untyped]
      def listed(index, principle_id)
        entries = index.fetch("index").map { it.merge("part" => ShellWord.new(it.fetch("part")).to_s) }
        { "request_id" => index.fetch("request_id"),
          "part_command" => @invocation.in_project("start-audit", principle_id, options: ["--part"]),
          "index" => entries }
      end
    end
  end
end

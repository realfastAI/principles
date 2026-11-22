# typed: strict
# frozen_string_literal: true

require_relative "context_parts"
require_relative "invocation"
require_relative "prompts"
require_relative "shell_word"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How to fill an answer this tool prints bare: save it to a file outside the project, named in full, fill it
    # there with the agent's own file-edit tool, and submit that file, with the three characters JSON escapes.
    # Filling a template in a shell heredoc took a script, since prose full of quotes needed escaping for the shell
    # and for JSON.
    class AnswerInAFile
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The line for a full audit's assessment, whose answer start-audit --part response_template prints bare.
      #: (String, request_id: String) -> String
      def assessment(principle_id, request_id:)
        line(@invocation.in_project("start-audit", principle_id, options: ["--part", ContextParts::TEMPLATE]),
             request_id:)
      end

      # The line for acknowledging member_ids of principle_ids, whose answer start-audit --member --as template prints
      # bare.
      #: (Array[String], Array[String], request_id: String) -> String
      def acknowledgement(principle_ids, member_ids, request_id:)
        named = member_ids.flat_map { ["--member", it] }
        line(@invocation.listed_in_project("start-audit", principle_ids, options: [*named, "--as", "template"]),
             request_id:)
      end

      # The line for a decision on principle_id's open findings, whose answer start-audit --open-findings --as template
      # prints bare.
      #: (String, request_id: String) -> String
      def open_findings(principle_id, request_id:)
        line(@invocation.in_project("start-audit", principle_id, options: %w[--open-findings --as template]),
             request_id:)
      end

      # The line for an open correction, whose answer show-open-correction prints bare, of which only the
      # dispositions are the agent's to fill.
      #: (String, request_id: String) -> String
      def correction(principle_id, request_id:)
        line(@invocation.in_project("show-open-correction", principle_id), request_id:, what: "only its dispositions")
      end

      # The line for the answer request_id names, which the printed command save prints bare; what is the part of it
      # the agent fills.
      #: (String, request_id: String, ?what: String) -> String
      def line(save, request_id:, what: "it")
        file = @invocation.answer_file(request_id)
        Prompts.text("answer-any-judgement-request/fill-the-answer-in-a-file",
                     save: "#{save} > #{ShellWord.new(file)}", what:,
                     answer_with: @invocation.submit_answer(request_id, file:))
      end
    end
  end
end

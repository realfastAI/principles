# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/disposition_placeholders"
require_relative "../models/open_correction"
require_relative "../views/answer_head"
require_relative "../views/correction_request"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # show-open-correction: the answer to fill for the correction a full audit's assessment with findings opened,
    # printed from the open record that keeps it, which submit-answer names rather than prints, and whenever the
    # agent loses it, without submitting the assessment again.
    class OpenCorrection < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, id, _options)
        naming_the_executable do
          unknown(command) unless command == "show-open-correction"

          principle_id = required_id(id)
          @principles.find(principle_id)
          correction_to_fill(principle_id)
        end
      end

      private

      # The open correction's answer alone, as show-answer-check --as template prints it before the submit.
      #: (String) -> Hash[String, untyped]
      def correction_to_fill(principle_id)
        kept = Models::OpenCorrection.kept(principle_id, @audit_records.find(principle_id),
                                           file: @audit_records.file(principle_id))
        head = Views::AnswerHead.new(request_id: kept.request_id, basis: kept.basis)
        placeholders = Models::DispositionPlaceholders::TEMPLATE_PLACEHOLDERS
        Views::CorrectionRequest.new(head:, principle_id:, findings: kept.findings, placeholders:).correction_to_fill
      end
    end
  end
end

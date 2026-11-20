# typed: strict
# frozen_string_literal: true

require_relative "prompts"
require_relative "request_part"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How a full audit shows the findings other principles leave open on members sharing its members' lines: each
    # once, which mapped_elsewhere names by id, with what to do with them.
    class OpenFindingsElsewhereResult
      # The part this lists, by the name the request prints it under and start-audit --part takes.
      PART = "open_findings_elsewhere" #: String

      # findings are each such finding, with its principle, id, problem and action.
      #: (Array[Hash[String, untyped]]) -> void
      def initialize(findings)
        @findings = findings
        freeze
      end

      # The assessment request's part that lists them and says what to do with them; nil when there are none. It adds
      # nothing to the template: a finding here is decided in its own principle's audit.
      #: () -> RequestPart?
      def part
        return if @findings.empty?

        text = Prompts.text("assess-every-member/name-another-principles-open-finding-rather-than-raise-it")
        instruction = Instruction.of_paragraphs("open_findings_elsewhere_instruction", text) { true }
        RequestPart.new(shown: { PART => @findings }, slots: {}, instructions: [instruction])
      end
    end
  end
end

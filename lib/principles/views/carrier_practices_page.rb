# typed: strict
# frozen_string_literal: true

require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One carrier kind's practices page: a title, then the kind's check, the one paragraph a request prints where the
    # agent judges or edits a member of the kind, then the depth show-carrier-practices prints. The check opens the
    # page, so the two have one owner.
    class CarrierPracticesPage
      # Each kind's page, as CarrierKind names the kinds.
      PAGES = {
        "instructions" =>
          -> { Prompts.markdown("follow-each-carriers-best-practices/practices-for-instruction-files") },
        "rule" => -> { Prompts.markdown("follow-each-carriers-best-practices/practices-for-rule-files") },
        "skill" => -> { Prompts.markdown("follow-each-carriers-best-practices/practices-for-skills") },
        "subagent" => -> { Prompts.markdown("follow-each-carriers-best-practices/practices-for-subagent-definitions") },
        "hook_configuration" =>
          -> { Prompts.markdown("follow-each-carriers-best-practices/practices-for-hook-configuration") },
        "hook_script" => -> { Prompts.markdown("follow-each-carriers-best-practices/practices-for-hook-scripts") },
        "none" => -> { Prompts.markdown("follow-each-carriers-best-practices/practices-for-other-text-an-agent-reads") }
      }.freeze #: Hash[String, ^() -> String]

      # The page of kind, one of PAGES' keys.
      #: (String) -> CarrierPracticesPage
      def self.of(kind) = new(PAGES.fetch(kind).call)

      #: (String) -> void
      def initialize(markdown)
        @body = markdown.strip #: String
        freeze
      end

      # The page, as show-carrier-practices prints it.
      #: String
      attr_reader :body

      # show-carrier-practices' result for kind, this page's.
      #: (String) -> Hash[String, untyped]
      def result(kind) = { "carrier" => kind, "practices" => body, "wrote" => [] }

      # The page's opening paragraph after its title, its lines joined, as a request prints it.
      #: () -> String
      def check = body.split(/\n{2,}/).fetch(1).gsub(/\s*\n\s*/, " ")
    end
  end
end

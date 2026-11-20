# typed: strict
# frozen_string_literal: true

require_relative "template_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The findings an assessment answer raises, as start-audit --as template prints one to fill: a finding sent back
    # exactly as printed raises none, and one otherwise filled may not keep a text field as printed.
    class NewFindings
      # The text fields of the printed finding, which their own check accepts as written text, so a field left as
      # printed in a finding otherwise filled is refused here. A member id or evidence left as printed is
      # refused by its own check.
      TEXT = TemplatePlaceholders.new(
        { "id" => "Only for a problem you found: an id such as F1. Leave this finding as printed to raise none",
          "problem" => "What is wrong, in the members' own words",
          "consequence" => "What it costs an agent that reads them",
          "proposed_action" => "What would fix it. Fixing, deferring or accepting it is decided in the correction" }
      ) #: TemplatePlaceholders

      # The finding the template printed alone gives to fill, which an answer leaves as printed to raise none; whether
      # to fix, defer or accept a finding is the correction's, so the finding itself carries none.
      TEMPLATE = {
        "id" => TEXT.fetch("id"), "member_ids" => ["The id of each member it concerns"],
        "problem" => TEXT.fetch("problem"), "consequence" => TEXT.fetch("consequence"),
        "proposed_action" => TEXT.fetch("proposed_action"),
        "evidence" => [{ "path" => "Where it shows: a path, with heading, starting_at or query to narrow it" }]
      }.freeze #: Hash[String, untyped]

      # findings is the answer's findings as sent, a list once its shape is checked.
      #: (Array[untyped]) -> void
      def initialize(findings)
        @findings = findings
        freeze
      end

      # The findings the answer raises: each but one sent back as the template printed it.
      #: () -> Array[untyped]
      def raised = @findings.reject { it == TEMPLATE }

      # Each text field a raised finding leaves as the template printed it, named by the finding's place and the
      # field, with its pointer, which the answer refuses with every other judgement left so.
      #: () -> Hash[String, String]
      def left_as_printed
        @findings.each_with_index.flat_map do |finding, index|
          next [] if !finding.is_a?(Hash) || finding == TEMPLATE

          TEXT.to_h.keys.select { TEXT.left?(it, finding[it]) }
              .map { ["Finding #{index + 1} #{it}", "/findings/#{index}/#{it}"] }
        end.to_h
      end
    end
  end
end

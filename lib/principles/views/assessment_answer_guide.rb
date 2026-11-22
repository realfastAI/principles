# typed: strict
# frozen_string_literal: true

require_relative "assessed_members"
require_relative "instruction"
require_relative "json_on_one_line"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The guide to a full audit's answer shapes, printed under answer_guide with the entries whose case the request's
    # members hold.
    class AssessmentAnswerGuide
      #: (AssessedMembers) -> void
      def initialize(members)
        @members = members
        freeze
      end

      # The answer guide, showing check_result's fields only when a member has a check, so an audit
      # with no checks costs no more context than before, and delivery's shapes only when a member is judged
      # afresh, since a carried member's marker gives none. check_result's limits say how to review a check
      # before running it only when a check is new or changed, as that check's own template says too.
      #: () -> GuideInstruction
      def instruction
        guide = with_examples_on_lines(Prompts.data("assess-every-member/answer-guide"))
        narrowed = @members.check_to_review? ? {} : guide.slice("check_result")
        GuideInstruction.new("answer_guide", guide.merge("check_result" => reviewed(guide.fetch("check_result"))),
                             narrowed:) do |entry|
          case entry
          when "check_result" then @members.checked?
          when "member_delivery" then @members.judged_afresh?
          else true
          end
        end
      end

      private

      # guide with each entry's examples printing compact, a line each, since the agent copies each one whole.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def with_examples_on_lines(guide)
        guide.transform_values do |entry|
          next entry unless entry.is_a?(Hash) && entry.key?("examples")

          entry.merge("examples" => entry.fetch("examples").transform_values { JsonOnOneLine[it] })
        end
      end

      # check_result's guide entry whole, its limits ending with how to review a new or changed check before running it.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def reviewed(check_result)
        review = Prompts.text("assess-every-member/review-a-new-or-changed-check-before-running-it")
        check_result.merge("limits" => "#{check_result.fetch("limits")} #{review}")
      end
    end
  end
end

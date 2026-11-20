# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_text"
require_relative "template_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One decision in an assessment's loading_decisions on a member the audit listed to check against the
    # activation. Whether the member should load as it does is the agent's judgement; this tool checks the
    # decision's shape.
    class LoadingDecision
      # The reason start-audit --as template prints in each decision, which left as printed is not given.
      PLACEHOLDERS = TemplatePlaceholders.new(
        { "reason" => "One line saying why the member loads as it does" }
      ) #: TemplatePlaceholders

      # decision is as the answer gave it, a reason left as its placeholder not given; index is its place in
      # loading_decisions.
      #: (untyped, Integer) -> void
      def initialize(decision, index)
        @decision = decision.is_a?(Hash) ? PLACEHOLDERS.given(decision) : {} #: Hash[String, untyped]
        @index = index
        freeze
      end

      # The member this decides, or "" when the decision names none.
      #: () -> String
      def member_id = @decision["member_id"].to_s

      # What the record keeps of this decision: its reason, or for kept the last accepted reason, and the loads it
      # accepted, from its member's row in the listing; refused unless the decision is one the record can keep.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def kept(row)
        check(row)
        reason = @decision["decision"] == "kept" ? row.dig("last_accepted", "reason") : @decision["reason"]
        { "reason" => reason, "loads" => row.fetch("loads") }
      end

      private

      # Refuses the decision unless it is accepted with a one-line reason, or kept on a member row whose loading
      # the last audit accepted and is unchanged since, so its reason still holds.
      #: (Hash[String, untyped]) -> void
      def check(row)
        return if @decision["decision"] == "accepted" && AnswerText.new(@decision["reason"]).written?
        return if @decision["decision"] == "kept" && row.dig("last_accepted", "since_accepted") == "unchanged"

        raise Error.new("invalid_loading_decision",
                        "loading_decisions[#{@index}] for #{@decision["member_id"]} needs decision accepted with a " \
                        "reason, or kept where its last_accepted.since_accepted is unchanged",
                        "Give decision accepted with a one-line reason why the member loads as it does, or kept to " \
                        "repeat the last accepted reason while since_accepted is unchanged, or, if the " \
                        "activation is what is wrong, change it with change-activation and run start-audit again, " \
                        "as the request's loads_to_check_instruction says; a finding decision is not built yet.")
      end
    end
  end
end

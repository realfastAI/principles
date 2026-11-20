# typed: strict
# frozen_string_literal: true

require_relative "template_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The fields a decision on a prior finding may give, as start-audit --as template prints them to fill: each with
    # a placeholder saying which decisions take it, so the agent fills those its decision takes and leaves the rest
    # as printed, which is not giving them. A marked finding's decision may start problem_evidence as an empty
    # list instead, which is not given either.
    module PriorDecisionFields
      # The decision's placeholder, naming what it may be; one sent back is no decision, named in the answer's
      # one refusal for every judgement left as printed.
      DECISION = "still_holds, resolved, withdrawn or raised_again" #: String
      # The fields that take pointers, which the answer's schema lets be text only for their placeholders.
      POINTERS = %w[evidence recorded_at problem_evidence].freeze #: Array[String]
      # raised_in's placeholder, in plain words, since the answer's schema accepts it as the one alternative to a full
      # sha, the only value that reaches git.
      RAISED_IN = "With first_raised_at: its record's commit, full sha; else leave" #: String
      # The placeholder printed in each field a decision may give: only which decision takes it, and what, since that
      # a field left as printed is not given is stated once, at the template's head, and each finding printed every
      # field's whole help. Each says what to do otherwise: "else kept" where omission keeps what the finding
      # has, "else leave" where it gives nothing. action's says instead that it is a change, which only
      # still_holds may make, since naming the decision read as a request to restate the action (dogfood D6).
      PLACEHOLDERS = TemplatePlaceholders.new(
        {
          "reason" => "resolved, withdrawn, new action: why, in a line; else leave",
          "as" => "raised_again: the new finding's id; else leave",
          "evidence" => [{ "path" => "resolved: where the fix shows, with heading; else leave" }],
          "action" => "to change it: deferred or accepted; else kept",
          "recorded_at" => "still_holds: a new pointer; null drops it; else kept",
          "waits_on" => "deferral: whom it waits on, for what, or null; else kept",
          "problem" => "still_holds: restated if renamed or moved; else kept",
          "problem_evidence" => [{ "path" => "still_holds: where it shows, with heading, if not kept; else leave",
                                   "replaces" => "if moved: a lost item's position" }],
          "first_raised_at" => "still_holds, if dated late: an earlier audited_at; else leave",
          "raised_in" => RAISED_IN
        },
        empty_lists: ["problem_evidence"]
      ) #: TemplatePlaceholders
      # Every placeholder a prior finding's decision prints: the decision's, and each field's.
      TEMPLATE_PLACEHOLDERS = { "decision" => DECISION, **PLACEHOLDERS.to_h }.freeze #: Hash[String, untyped]
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "disposition_text_field"
require_relative "named_placeholder"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The text a correction's template prints in each disposition field the agent fills, which an answer may not
    # send back unchanged: each text field's, with what to write instead, and the action's. Each names the finding
    # of the disposition it is printed in, so no two dispositions' slots are alike and one edit fills one.
    class DispositionPlaceholders
      TEXT_FIELDS = {
        "reason" => DispositionTextField.new(
          placeholder: NamedPlaceholder.new("Why #{NamedPlaceholder::SLOT} takes this action, and what remains",
                                            before: "Why, and what remains"),
          repair: "Write why you chose this action and what remains."
        ),
        "reassessment" => DispositionTextField.new(
          placeholder: NamedPlaceholder.new(
            "fixed only: how the members changed for #{NamedPlaceholder::SLOT} now carry the principle. " \
            "Leave as printed otherwise",
            before: "fixed only: how the changed members now carry the principle. Leave as printed otherwise"
          ),
          repair: "Write how the changed members now carry the principle."
        )
      }.freeze #: Hash[String, DispositionTextField]
      # The placeholder in each field, which the template prints with the disposition's finding in its slot.
      PLACEHOLDERS = TEXT_FIELDS.transform_values { it.placeholder.slotted }.freeze #: Hash[String, String]
      # What action takes, said where it is written when the correction's answer is printed with no answer guide
      # beside it, as show-answer-check prints it, before it named the finding. It is help, never an action, so it
      # is left unchosen.
      ACTION_PLACEHOLDER = "One of fixed, deferred, accepted or disagreed, each with a reason: fixed lists " \
                           "changed_members for current text changes, optional removed_members for map removals, " \
                           "and evidence and gives a reassessment; deferred gives recorded_at, " \
                           "where the write-up is, and may give waits_on; any other action leaves changed_members, " \
                           "evidence and reassessment as printed" #: String
      # The action's placeholder, naming the finding.
      ACTION = NamedPlaceholder.new("For #{NamedPlaceholder::SLOT}, #{ACTION_PLACEHOLDER.sub(/\AO/, "o")}",
                                    before: ACTION_PLACEHOLDER) #: NamedPlaceholder
      # Every placeholder a slot of a correction's template prints, for any finding.
      NAMED = [*TEXT_FIELDS.values.map(&:placeholder), ACTION].freeze #: Array[NamedPlaceholder]
      # Every placeholder a correction's template prints, each text field's and the action's, each with its slot.
      TEMPLATE_PLACEHOLDERS = PLACEHOLDERS.merge("action" => ACTION.slotted).freeze #: Hash[String, String]
    end
  end
end

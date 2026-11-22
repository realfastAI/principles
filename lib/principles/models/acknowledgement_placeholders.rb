# typed: strict
# frozen_string_literal: true

require_relative "acknowledgement_left_as_printed"
require_relative "named_placeholder"
require_relative "reported_check"
require_relative "template_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The text a one-member audit's template prints in each field the agent writes, and the refusal of an answer
    # that sends any back as printed.
    class AcknowledgementPlaceholders
      # The text the answer's template prints in each field the agent judges, which an answer may not send back, so
      # a template returned as printed acknowledges nothing. It prints no quotes, which an answer leaving them
      # out reads as first_changed_lines. After a pure insertion, meaning_kept's says that an
      # inserted line usually adds a rule, for an agent that reads the template alone.
      # Each names the member of the entry it is printed in, so no two members' slots are alike and one edit fills
      # one; any member's, or the text printed before each named one, is left as printed.
      PLACEHOLDERS = TemplatePlaceholders.new(
        { "meaning_kept" => NamedPlaceholder.new("true only if #{NamedPlaceholder::SLOT} still says the same thing",
                                                 before: "true only if the member still says the same thing"),
          "reason" => NamedPlaceholder.new("Why, for #{NamedPlaceholder::SLOT}, in one line of your own",
                                           before: "Why, in one line of your own") },
        also_printed: { "meaning_kept" => NamedPlaceholder.new(
          "true only if #{NamedPlaceholder::SLOT} still says the same thing; this change inserted a line, which " \
          "usually adds a rule",
          before: "true only if the member still says the same thing; this change inserted a line, which usually " \
                  "adds a rule"
        ) }
      ) #: TemplatePlaceholders
      # The text a checked member's template prints where its check's exit status goes, short since the request's
      # context says how to run the check.
      EXIT_STATUS_PLACEHOLDER = ReportedCheck::EXIT_STATUS_PLACEHOLDER #: String
      # The fields an answer may not send back as the template printed them, refused before its shape.
      LEFT_AS_PRINTED = AcknowledgementLeftAsPrinted.new(
        PLACEHOLDERS, exit_status: EXIT_STATUS_PLACEHOLDER
      ) #: AcknowledgementLeftAsPrinted

      # The placeholders the template prints beside quotes, its first_changed_lines.
      #: (Hash[String, String]) -> Hash[String, untyped]
      def self.beside(quotes)
        quotes["old_line"] == "" ? PLACEHOLDERS.with_other_text_in("meaning_kept") : PLACEHOLDERS.to_h
      end
    end
  end
end

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
      # meaning_kept's placeholder after a pure insertion, for an agent that reads the template alone: an inserted
      # line usually adds a rule.
      INSERTED = NamedPlaceholder.new(
        "M#{NamedPlaceholder::SLOT}: true only if it still says the same thing; this change inserted a line, " \
        "which usually adds a rule",
        before: NamedPlaceholder.new(
          "true only if #{NamedPlaceholder::SLOT} still says the same thing; this change inserted a line, which " \
          "usually adds a rule",
          before: "true only if the member still says the same thing; this change inserted a line, which " \
                  "usually adds a rule"
        )
      ) #: NamedPlaceholder
      # meaning_kept's placeholder when the member's lines grew and its file's text did not change, as after
      # move-member --ending-at, where no line was inserted; it printed INSERTED before.
      SPAN_GREW = NamedPlaceholder.new(
        "M#{NamedPlaceholder::SLOT}: true only if it still says the same thing; its span grew over lines its file " \
        "already held, which may add a rule",
        before: INSERTED
      ) #: NamedPlaceholder
      # The text the answer's template prints in each field the agent judges, which an answer may not send back, so
      # a template returned as printed acknowledges nothing. It prints no quotes, which an answer leaving them
      # out reads as first_changed_lines. After a pure insertion, meaning_kept's is INSERTED, or SPAN_GREW when the
      # file's text did not change.
      # Each names the entry it is printed in by its position, M1 the first, so no two members' slots are alike and
      # one edit fills one, short since an edit tool's old_string quotes it whole; the member's id, which may be long
      # and hold quotes, is the entry's key alone. Any entry's, or the text printed before, naming the member's id or
      # neither, is left as printed.
      PLACEHOLDERS = TemplatePlaceholders.new(
        { "meaning_kept" => NamedPlaceholder.new(
          "M#{NamedPlaceholder::SLOT}: true only if it still says the same thing",
          before: NamedPlaceholder.new("true only if #{NamedPlaceholder::SLOT} still says the same thing",
                                       before: "true only if the member still says the same thing")
        ),
          "reason" => NamedPlaceholder.new(
            "M#{NamedPlaceholder::SLOT}: why, in one line of your own",
            before: NamedPlaceholder.new("Why, for #{NamedPlaceholder::SLOT}, in one line of your own",
                                         before: "Why, in one line of your own")
          ) },
        also_printed: { "meaning_kept" => { inserted: INSERTED, span_grew: SPAN_GREW } }
      ) #: TemplatePlaceholders
      # The text a checked member's template prints where its check's exit status goes, short since the request's
      # context says how to run the check.
      EXIT_STATUS_PLACEHOLDER = ReportedCheck::EXIT_STATUS_PLACEHOLDER #: String
      # The fields an answer may not send back as the template printed them, refused before its shape.
      LEFT_AS_PRINTED = AcknowledgementLeftAsPrinted.new(
        PLACEHOLDERS, exit_status: EXIT_STATUS_PLACEHOLDER
      ) #: AcknowledgementLeftAsPrinted

      # The placeholders the template prints beside quotes, its first_changed_lines, file_unchanged saying whether
      # the member's file holds the same text as at its baseline, so only its span changed.
      #: (Hash[String, String], ?file_unchanged: bool) -> Hash[String, untyped]
      def self.beside(quotes, file_unchanged: false)
        return PLACEHOLDERS.to_h unless quotes["old_line"] == ""

        PLACEHOLDERS.with_other_text_in("meaning_kept", file_unchanged ? :span_grew : :inserted)
      end
    end
  end
end

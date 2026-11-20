# typed: strict
# frozen_string_literal: true

require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What a checked member's exit_status placeholder says of its check beside what to do, in a full audit's template
    # and a one-member audit's alike: any hidden character the command holds, and the line the last audit's
    # review rested on, which a run keeps unless a new one is given.
    class CheckNotes
      # Since when a line an audit still open kept was given, which that audit dates as it completes.
      OPEN_SINCE = "this audit's open assessment" #: String

      # since_last_audit is how the check stands to the last audit's, with the review line that audit kept, if any;
      # hidden_characters names each hidden character in the command.
      #: (Hash[String, untyped]?, Array[String]) -> void
      def initialize(since_last_audit, hidden_characters)
        @since_last_audit = since_last_audit
        @hidden_characters = hidden_characters
        freeze
      end

      # The note naming the command's hidden characters, where the decision to run it is made; nil when it has none.
      #: () -> String?
      def hidden_characters
        return if @hidden_characters.empty?

        Prompts.text("assess-every-member/have-hidden-characters-in-a-check-explained",
                     characters: @hidden_characters.join("; "))
      end

      # The line the last audit's review rested on, which a full audit's template prints as review_basis's value to
      # keep or replace; nil when that audit kept none.
      #: () -> String?
      def kept_basis = @since_last_audit&.fetch("review_basis", nil)

      # That review_basis holds the line the last audit's review rested on, with since when, kept as printed unless
      # replaced, for a template that prints it; nothing when that audit kept none.
      #: () -> Array[String]
      def printed_review
        return [] unless kept_basis

        [Prompts.text("assess-every-member/keep-the-printed-review-basis-or-replace-it", since: since)]
      end

      # That a run keeps the line the last audit's review rested on, quoted with since when, unless a new one is
      # given, so whether it still holds can be judged from the template; an older record kept none,
      # so there is nothing to say.
      #: () -> Array[String]
      def kept_review
        return [] unless @since_last_audit&.key?("review_basis")

        [Prompts.text("assess-every-member/keep-the-last-review-basis-unless-you-give-a-new-one",
                      since: since, basis: @since_last_audit.fetch("review_basis"))]
      end

      private

      # Since when the kept line was first kept: its date, or, while the audit that kept it is still open and so has
      # not dated it, that audit's assessment.
      #: () -> String
      def since = @since_last_audit&.fetch("review_basis_since", nil) || OPEN_SINCE
    end
  end
end

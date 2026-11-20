# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_text"
require_relative "dated_line"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The one line an answer may give on a deferred finding, saying whom it waits on and to decide what.
    # What the line says is the agent's judgement; this tool checks only that it is one line, on a finding left
    # deferred. A null stands on any finding, so a template's null kept on another action is not refused.
    class WaitsOn
      # What to write instead of a line this tool cannot keep.
      REPAIR = "Say in one line whom the deferral waits on and to decide what, or set waits_on to null." #: String

      # line is what the answer gave, and action the finding's action once the answer is applied, or nil when the
      # answer does not leave it open.
      #: (untyped, action: String?) -> void
      def initialize(line, action:)
        @line = line
        @action = action
        freeze
      end

      # Refuses the line, with code and naming subject, unless it is null, or one line on a finding left deferred.
      #: (code: String, subject: String) -> void
      def check(code:, subject:)
        return if @line.nil?

        unless deferred?
          raise Error.new(code, "#{subject} gives waits_on, but only a deferred finding waits on anyone",
                          "Set waits_on to null, or defer the finding.")
        end
        return if AnswerText.new(@line).one_line?

        raise Error.new(code, "#{subject} gives a waits_on that is not one line", REPAIR)
      end

      # What a kept finding waits on once its decision is applied, this being the line the decision gave or, when it
      # gave none, the one it carried: had, the waits_on and waits_on_since it carried, when the line is unchanged,
      # so an ask keeps its date; this line alone, dated by the audit that records it, when new; nothing when the
      # finding is no longer deferred or the decision gave null.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def kept_over(had)
        return {} unless deferred?

        DatedLine.new(@line, field: "waits_on").kept_over(had)
      end

      private

      #: () -> bool
      def deferred? = @action == "deferred"
    end
  end
end

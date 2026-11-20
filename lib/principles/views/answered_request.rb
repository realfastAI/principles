# typed: strict
# frozen_string_literal: true

module Principles
  module Views
    # An answered request's terminal result fields, with no further correction template to fill.
    class AnsweredRequest
      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields
        freeze
      end

      #: (AuditResult) -> Hash[String, untyped]
      def presented_with(_view) = @fields

      #: (Hash[String, untyped], Invocation, String) -> Hash[String, untyped]
      def with_correction_to_fill(acceptable, _invocation, _answer_file) = acceptable

      # No correction follows a terminal answer, so there is none to fill.
      #: () -> nil
      def correction_to_fill = nil
    end
  end
end

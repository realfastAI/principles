# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A line an answer gives that a record keeps under field, with field_since, the date it was first given, beside
    # it: the same line keeps its date, a new line is dated afresh by the audit that records it, and null drops it.
    class DatedLine
      # line is what the answer gave, nil for none; field is the name the record keeps it under.
      #: (untyped, field: String) -> void
      def initialize(line, field:)
        @line = line
        @field = field
        freeze
      end

      # The line as the record keeps it, given had, the line and date it carried: had when the line is unchanged, so
      # it keeps its date; this line alone, which the record's audited_at dates, when new; nothing when it is null.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def kept_over(had)
        return had if @line == had[@field]

        @line.nil? ? {} : { @field => @line }
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../prose_list"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The note a full audit's request and its index of parts print, naming the instructions the request prints only in
    # part and the flag that prints one whole, so a trimmed field is not taken for the whole.
    class TrimmedInstructionsNote
      # fields is each instruction field the request prints only in part, in order.
      #: (Array[String]) -> void
      def initialize(fields)
        @fields = fields
        freeze
      end

      # The note under trimmed_instructions; nothing when the request trims none.
      #: () -> Hash[String, String]
      def to_h
        return {} if @fields.empty?

        { "trimmed_instructions" => Prompts.text("assess-every-member/read-a-trimmed-instruction-whole",
                                                 fields: ProseList.new(@fields).to_s) }
      end
    end
  end
end

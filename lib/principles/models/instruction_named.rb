# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The instruction field start-audit --instruction names, read whole from the request a full audit asks. Only a
    # field the request prints an instruction under can be read: the others explain fields it does not hold.
    class InstructionNamed
      #: (String, principle_id: String, printed: Array[String]) -> void
      def initialize(field, principle_id:, printed:)
        @field = field
        @id = principle_id
        @printed = printed
        freeze
      end

      # The field, refused unless the request prints an instruction under it.
      #: () -> String
      def field
        return @field if @printed.include?(@field)

        refusal = Error.new("unknown_instruction",
                            "This request prints no instruction named #{@field}. It prints #{ProseList.new(@printed)}.",
                            "")
        raise refusal.ending_with([Error::RepairCommand.new(purpose: "To print one whole", command: "start-audit",
                                                            values: [@id], usage: "--instruction FIELD")])
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The part start-audit --part names, printed alone from the request a full audit asks, so an agent that needs one
    # part of it need not read the whole request or script it. Only a part the request has, or leaves
    # out as empty, can be printed.
    class PartNamed
      # empty is each part the request lists only when it holds something, and leaves out now, which is named rather
      # than refused. template is whether the part is read from the answer --as template prints, whose parts are its
      # members' slots, rather than from the request.
      #: (String, principle_id: String, printed: Array[String], ?empty: Array[String], ?template: bool) -> void
      def initialize(part, principle_id:, printed:, empty: [], template: false)
        @part = part
        @id = principle_id
        @printed = printed
        @empty = empty
        @template = template
        freeze
      end

      # The part, refused unless the request, or its template, has it or leaves it out as empty.
      #: () -> String
      def part
        return @part if @printed.include?(@part) || @empty.include?(@part)

        whole = @template ? "template" : "request"
        refusal = Error.new("unknown_part",
                            "This #{whole} has no part named #{@part}. It has #{ProseList.new(@printed)}.", "")
        usage = @template ? "--as template --part PART" : "--part PART"
        raise refusal.ending_with([Error::RepairCommand.new(purpose: "To print one part", command: "start-audit",
                                                            values: [@id], usage:)])
      end
    end
  end
end

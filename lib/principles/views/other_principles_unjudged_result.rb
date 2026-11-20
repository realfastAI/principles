# typed: strict
# frozen_string_literal: true

require_relative "principle_with_changed_members"
require_relative "prompts"
require_relative "request_part"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How the meta-principle's full audit states, as a fact, each other principle with members no audit has judged
    # as they are now, which a check on its passage once reported, beside the release since its last audit.
    class OtherPrinciplesUnjudgedResult
      # The part this lists, by the name the request prints it under and start-audit --part takes.
      PART = "other_principles_with_unjudged_changes" #: String

      # principles holds each other principle with such members, by id with their states; empty when there are none.
      #: (Array[PrincipleWithChangedMembers]) -> void
      def initialize(principles)
        @principles = principles
        freeze
      end

      # The request's part listing them under principles, with why, how to weigh them, as the release part beside it
      # gives its own.
      #: () -> RequestPart
      def part
        why = Prompts.text("assess-every-member/judge-the-keeping-against-the-other-principles")
        RequestPart.new(shown: { PART => { "principles" => @principles.map(&:to_h),
                                           "why" => why } },
                        slots: {})
      end
    end
  end
end

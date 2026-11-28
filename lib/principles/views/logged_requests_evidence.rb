# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "logged_request_status_meanings"
require_relative "prompts"
require_relative "request_part"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What a full audit's request prints from the logged requests, so the agent judging each
    # member sees whether its text reached the agent's context: here, while none is captured, the one line saying how
    # to capture them; while git might commit them or a tool the scan runs is missing, why none is read; and else how
    # far each judged member's text reached them.
    class LoggedRequestsEvidence
      # The part this prints, by the name the request prints it under and start-audit --part takes.
      PART = "logged_requests" #: String

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The request's part saying that no request is captured, and the command that turns capture on.
      #: () -> RequestPart
      def none_captured
        turn_on = @invocation.in_project("turn-on-request-logging")
        fact = Prompts.text("assess-every-member/turn-on-request-logging-to-see-what-reaches-context", turn_on:)
        RequestPart.new(shown: { PART => { "fact" => fact } }, slots: {})
      end

      # The request's part saying how far each judged member's text reached the captured requests, as reach gives it,
      # with the command that shows where in the requests one member was seen, its key as KEY, what each status
      # means, and the question that asks the agent to weigh it.
      #: (Hash[String, untyped]) -> RequestPart
      def reached(reach)
        detail = @invocation.in_project("show-members-in-logged-requests", options: ["--member", "KEY"])
        weigh = Prompts.text("assess-every-member/weigh-what-reached-the-context")
        shown = reach.merge("detail_with" => detail, "status_meanings" => LoggedRequestStatusMeanings.new.to_h,
                            "weigh" => weigh)
        RequestPart.new(shown: { PART => shown }, slots: {})
      end

      # The request's part, by its name alone, for a read of the request that prints none of it, so the captured
      # requests go unscanned, with why the index gives no bytes for it; it adds no slot to the answer.
      #: () -> RequestPart
      def not_scanned = NotScanned.new(shown: { PART => {} }, slots: {})

      # The part a read left unscanned, which the index gives no bytes for, since sizing it would wait on the scan.
      class NotScanned < RequestPart
        # Why the index gives no bytes for this part.
        #: () -> String
        def bytes_unknown
          "Reading this part scans the logged requests, so the index does not size it; read it with part_command."
        end
      end

      # The request's part saying why no logged request is read, from the refusal a read of them gives: its message
      # as the fact, and its repair.
      #: (Hash[String, untyped]) -> RequestPart
      def unread(refusal)
        RequestPart.new(shown: { PART => { "fact" => refusal.fetch("message"), "repair" => refusal.fetch("repair") } },
                        slots: {})
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "prior_findings"
require_relative "request_id"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # An answer submitted to the request request_id names, its shape checked, with the prior findings a full
    # audit's request listed, which checking its head found, or nil for any other phase.
    class SubmittedAnswer
      #: RequestId
      attr_reader :request_id

      #: untyped
      attr_reader :response

      #: (RequestId, untyped, PriorFindings?) -> void
      def initialize(request_id, response, prior)
        @request_id = request_id
        @response = response
        @prior = prior
        freeze
      end

      # The prior findings a full audit's assessment request listed, which only that phase's answer has.
      #: () -> PriorFindings
      def prior_findings
        @prior or raise ArgumentError, "an assessment's prior findings come from checking its head"
      end
    end
  end
end

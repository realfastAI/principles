# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What an answer hands back unchanged, at its head: the id of the request it answers and that request's basis,
    # which the agent never copies by hand.
    class AnswerHead
      #: String
      attr_reader :request_id

      #: (request_id: String, basis: Hash[String, untyped]) -> void
      def initialize(request_id:, basis:)
        @request_id = request_id
        @basis = basis
        freeze
      end

      # Whether the basis names a base commit, as in git; outside git it names none.
      #: () -> bool
      def based_on_a_commit? = !@basis["base_commit"].nil?

      # The answer's fields, after its request id and basis.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def leading(fields) = { "request_id" => @request_id, "basis" => @basis }.merge(fields)
    end
  end
end

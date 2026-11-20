# typed: strict
# frozen_string_literal: true

require_relative "member_file"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A refusal to locate a member, as its payload gives it, and what it makes of the member's state: lost in its
    # file when its place there is gone, or else unavailable, as when its file cannot be read.
    class LocateRefusal
      #: (Hash[String, untyped]) -> void
      def initialize(payload)
        @payload = payload
        freeze
      end

      # locator_lost when its code says the member's place in its file is gone, or else unavailable.
      #: () -> String
      def member_state = MemberFile::PLACE_LOST.include?(@payload["code"]) ? "locator_lost" : "unavailable"
    end
  end
end

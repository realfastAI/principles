# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # How far one member's text reached the captured requests, from the places the scan saw it: how many requests
    # held its lines, and the most bytes of them one request held.
    class MemberReach
      # member is one member as the scan reports it, with its status and the places it was seen.
      #: (Hash[String, untyped]) -> void
      def initialize(member)
        @member = member
        freeze
      end

      # Its key, its id where it is now once moved, status, the requests seen holding its lines and its most bytes in
      # one.
      #: () -> Hash[String, untyped]
      def to_h
        by_request = @member.fetch("seen").group_by { it.fetch("request") }.values
        bytes = by_request.map { |places| places.sum { it.fetch("bytes") } }
        { **@member.slice("member", "id"),
          "status" => @member.fetch("status"), "seen_in" => bytes.size, "most_bytes" => bytes.max || 0 }
      end

      # Its reach as to_h gives it, after its principle, with the segments it was seen in, each once: bounded by the
      # member, however many requests and places hold it.
      #: () -> Hash[String, untyped]
      def listed
        { "principle" => @member.fetch("principle"), **to_h,
          "segments" => @member.fetch("seen").map { it.fetch("segment") }.uniq }
      end
    end
  end
end

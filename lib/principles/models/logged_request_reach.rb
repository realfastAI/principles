# typed: strict
# frozen_string_literal: true

require_relative "member_reach"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # How far each member's text reached, compactly, from where the scan of the captured requests saw it: how many of
    # the scanned requests held its lines, and the most bytes of them one request held. A full audit's request prints
    # it, so the agent judging a member weighs whether it reaches the agent and what it costs there.
    class LoggedRequestReach
      # members is each member as the scan reports it, with its status and the places it was seen; scanned is how many
      # requests the scan read whole, and unreadable how many it could not, since what they held is unknown; carried
      # names each member a full audit carries forward, which is listed too, marked, since one that never loads still
      # fails its principle.
      #: (Array[Hash[String, untyped]], scanned: Integer, ?unreadable: Integer, ?carried: Array[String]) -> void
      def initialize(members, scanned:, unreadable: 0, carried: [])
        @members = members
        @carried = carried
        @scanned = scanned
        @unreadable = unreadable
        freeze
      end

      # The requests scanned, any it could not read, and each member's status, the requests seen holding its lines and
      # its most bytes in one, and whether the audit carries it forward.
      #: () -> Hash[String, untyped]
      def to_h
        { "requests" => @scanned, **({ "unreadable" => @unreadable } if @unreadable.positive?),
          "members" => @members.map { reach(it) } }
      end

      private

      # member's reach, marked when the audit carries it forward.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def reach(member)
        reach = MemberReach.new(member).to_h
        @carried.include?(member.fetch("member")) ? reach.merge("carried_forward" => true) : reach
      end
    end
  end
end

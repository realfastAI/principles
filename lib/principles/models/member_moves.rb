# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member"
require_relative "principle"

module Principles
  # The domain: maps, audits and command steps, with every rule a schema cannot express.
  # models/CLAUDE.md owns the boundary.
  module Models
    # The members a correction says the agent moved after the audit began, from each old id to its new one. A
    # fix can rewrite the text a member's locator quotes; the agent then runs move-member and declares the
    # move, and this tool checks it against the map at the base commit.
    class MemberMoves
      #: (untyped) -> void
      def initialize(moves)
        @moves = parsed(moves) #: Hash[String, String]
        freeze
      end

      #: () -> bool
      def empty?
        @moves.empty?
      end

      # Whether any id participates in either end of a declared move, including a move keeping its id.
      #: (Array[String]) -> bool
      def involving_any?(ids) = @moves.keys.intersect?(ids) || @moves.values.intersect?(ids)

      # Refuses moves outside git, where there is no base map to check them against.
      #: (String?, principle_id: String) -> String
      def check_in_git(base, principle_id:)
        return base if base

        raise Error.new("moves_need_git", "moved_members needs git, to read the map #{principle_id} began from",
                        "Outside git, start a fresh audit: #{Error::EXECUTABLE} start-audit #{principle_id}")
      end

      # The base map with each declared member moved to its place in current, each keeping its role.
      #: (Principle, Principle) -> Principle
      def applied(base, current)
        @moves.reduce(base) { |map, (from, to)| map.moving(from, located(current, to)) }
      end

      # The refusal of a map that changed beyond the moves declared.
      #: (String, String) -> Error
      def undeclared(principle_id, map_file)
        Error.new("undeclared_move", "The map of #{principle_id} changed during this audit beyond the moves declared",
                  "Declare each member you moved in moved_members, or start a fresh audit: " \
                  "#{Error::EXECUTABLE} start-audit #{principle_id}", map_file)
      end

      # The member's id after the declared moves.
      #: (String) -> String
      def renamed(member_id)
        @moves.fetch(member_id, member_id)
      end

      # Each finding with its members' ids after the moves.
      #: (Array[untyped]) -> Array[untyped]
      def findings(findings)
        findings.map { |finding| finding.merge("member_ids" => finding.fetch("member_ids").map { |id| renamed(id) }) }
      end

      # The values in by_id, such as each member's hash or its record entry's fields, keyed by each member's id
      # after the moves.
      #: [V] (Hash[String, V]) -> Hash[String, V]
      def hashes(by_id)
        by_id.transform_keys { |id| renamed(id) }
      end

      private

      #: (untyped) -> Hash[String, String]
      def parsed(moves)
        return {} if moves.nil?

        unless moves.is_a?(Array) && moves.all? { |move| move.is_a?(Hash) && move.values_at("from", "to").all?(String) }
          raise Error.new("invalid_answer", "moved_members must be a list of {\"from\": OLD_ID, \"to\": NEW_ID}",
                          "List each member you moved with move-member, by its id before and after.")
        end

        moves.to_h { |move| [move.fetch("from"), move.fetch("to")] }
      end

      # The current member to's place in its file, without its role.
      #: (Principle, String) -> Hash[String, untyped]
      def located(current, to)
        unless current.members.taken?(to)
          raise Error.new("unknown_member", "#{to} is not a member of #{current.id}",
                          "Name in moved_members the id show-principle lists after the move.")
        end

        current.members.found(to).to_h.except("role")
      end
    end
  end
end

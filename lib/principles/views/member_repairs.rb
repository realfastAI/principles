# typed: strict
# frozen_string_literal: true

require_relative "invocation"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The commands that repair a member this tool cannot find: each move Models::MemberRepairMoves gives, then
    # remove it. Which fits is the agent's to judge.
    class MemberRepairs
      # The flag that names each locator field in a printed command.
      FLAGS = { "section" => "--section", "starting_at" => "--starting-at", "ending_at" => "--ending-at",
                "query" => "--query", "path" => "--path" }.freeze #: Hash[String, String]
      # The placeholder the agent fills in for each field a move leaves to it.
      PLACEHOLDERS = { "section" => "HEADING", "starting_at" => "NEW_OPENING_TEXT",
                       "ending_at" => "NEW_ENDING_TEXT", "query" => "QUERY",
                       "path" => "NEW_PATH" }.freeze #: Hash[String, String]

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The repairs for member_id of principle id: each of moves, as Models::MemberRepairMoves gives them, the locator
      # fields it keeps and those to fill in, as a copyable move-member, then remove-member.
      #: (String, String, Array[Hash[String, untyped]]) -> Array[String]
      def commands(id, member_id, moves)
        [*moves.map { move(id, member_id, it) }, @invocation.in_project("remove-member", id, member_id)]
      end

      # member, as show-principle prints it, with its repairs as repair_with when moves, its moves, are given, as the
      # controller gives them for a member an audit would refuse.
      #: (String, Hash[String, untyped], Array[Hash[String, untyped]]?) -> Hash[String, untyped]
      def beside(id, member, moves)
        return member unless moves

        member.merge("repair_with" => commands(id, member.fetch("id"), moves))
      end

      private

      #: (String, String, Hash[String, untyped]) -> String
      def move(id, member_id, move)
        kept = move.fetch("keep").flat_map { |field, value| [FLAGS.fetch(field), value] }
        fill = move.fetch("fill")
        usage = fill.map { "#{FLAGS.fetch(it)} #{PLACEHOLDERS.fetch(it)}" }.join(" ") unless fill.empty?
        @invocation.in_project("move-member", id, member_id, options: kept, usage: usage)
      end
    end
  end
end

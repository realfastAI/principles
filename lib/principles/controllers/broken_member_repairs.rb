# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../models/mapped_principles"
require_relative "../models/member_repair_moves"
require_relative "../views/invocation"
require_relative "../views/member_repairs"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The repairs this tool prints for members it cannot find, in the project's maps: the moves
    # Models::MemberRepairMoves gives for each, printed by Views::MemberRepairs, beside a broken_members refusal or a
    # member show-principle shows.
    class BrokenMemberRepairs
      #: (Models::MappedPrinciples, Views::Invocation) -> void
      def initialize(principles, invocation)
        @principles = principles
        @repairs = Views::MemberRepairs.new(invocation) #: Views::MemberRepairs
        freeze
      end

      # A broken_members refusal, with each member's own repair commands beside it as repair_with, since a
      # model's repair can only name placeholders. Any other refusal is returned as it is.
      #: (Error) -> Error
      def beside(error)
        return error unless error.payload["code"] == "broken_members"

        members = error.payload.fetch("members").map do |entry|
          repaired({ "principle" => error.payload["principle"] }.compact.merge(entry))
        end
        error.including("members" => members)
      end

      # The moves that may repair member, which a refusal with code says this tool cannot find; tracked_as is the
      # spelling git tracks its path under, when the refusal names one.
      #: (Hash[String, untyped], code: String?, tracked_as: String?) -> Array[Views::MemberRepairs::Move]
      def moves(member, code:, tracked_as:)
        Models::MemberRepairMoves.new(member, code:, tracked_as:).to_a
                                 .map { Views::MemberRepairs::Move.new(keep: it.keep, fill: it.fill) }
      end

      private

      # entry with repair_with, when it names a member its map still lists.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def repaired(entry)
        principle = entry["principle"] or return entry
        id = entry["id"] or return entry
        member = @principles.find(principle).member(id)
        moves = moves(member, code: entry["code"], tracked_as: entry["tracked_as"])
        entry.merge("repair_with" => @repairs.commands(principle, id, moves))
      rescue Error
        entry
      end
    end
  end
end

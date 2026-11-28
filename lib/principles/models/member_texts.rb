# typed: strict
# frozen_string_literal: true

require_relative "whole_file_member_read"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Each member of a map's lines now, by id, without their line endings, which a full audit's request parts print
    # so the agent reads the text each member is judged on, and which members' text prints in a part of its own.
    class MemberTexts
      # listed is each member as the request lists it, which says whether the audit carries or judges it.
      #: (Project, Principle, listed: Array[Hash[String, untyped]]) -> void
      def initialize(project, map, listed:)
        @project = project
        @map = map
        @listed = listed.to_h { [it.fetch("id"), it] } #: Hash[String, Hash[String, untyped]]
        freeze
      end

      # Each member's lines now, by id.
      #: () -> Hash[String, Array[String]]
      def lines
        @map.members.to_h { [it.id, @project.member_file(it.path).lines_of(it.locator).map(&:chomp)] }
      end

      # The id of each member whose text prints in a part of its own, as WholeFileMemberRead decides.
      #: () -> Array[String]
      def apart_ids
        @map.members.select { read(it).text_apart? }.map(&:id)
      end

      # When the request says to read each member's text part whole, by id, as WholeFileMemberRead#read_whole says.
      #: () -> Hash[String, String]
      def read_whole
        @map.members.filter_map { |member| (when_read = read(member).read_whole) && [member.id, when_read] }.to_h
      end

      private

      #: (Member) -> WholeFileMemberRead
      def read(member) = WholeFileMemberRead.new(whole_file: member.whole_file?, listed: @listed.fetch(member.id))
    end
  end
end

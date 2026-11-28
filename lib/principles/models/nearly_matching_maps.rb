# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The other maps whose member set nearly matches a map's once a member joins it, so two maps carrying one
    # principle are seen as they are mapped. Nearly matching is a stated measure, compared by member id: at least
    # SHARED members held by both, and at least SHARE of the members either holds, when the new member is one of them.
    # It reports a fact the agent judges; it decides nothing.
    class NearlyMatchingMaps
      # The fewest members two maps share before their sets can nearly match; one shared member is a shared carrier.
      SHARED = 2 #: Integer

      # The least share of the members either map holds that both hold.
      SHARE = Rational(2, 3) #: Rational

      #: (Project, Principle, Member) -> void
      def initialize(project, map, member)
        @project = project
        @map = map
        @member = member
        freeze
      end

      # Each other map nearly matching, its id with the members both hold and the members either holds. A map that
      # cannot be read is left out, since list-member-problems reports it.
      #: () -> Array[Hash[String, untyped]]
      def elsewhere
        maps = @project.principles
        (maps.ids - [@map.id]).filter_map { |id| near(id, maps) }
      end

      private

      #: (String, MappedPrinciples) -> Hash[String, untyped]?
      def near(id, maps)
        ids = member_ids(@map)
        theirs = member_ids(maps.find(id))
        shared = (ids & theirs).length
        either = (ids | theirs).length
        return unless theirs.include?(@member.id) && shared >= SHARED && Rational(shared, either) >= SHARE

        { "principle_id" => id, "shared" => shared, "members_in_either" => either }
      rescue Error
        nil
      end

      #: (Principle) -> Array[String]
      def member_ids(map) = map.members.to_a.map(&:id)
    end
  end
end

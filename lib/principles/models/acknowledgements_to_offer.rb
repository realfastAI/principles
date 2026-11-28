# typed: strict
# frozen_string_literal: true

require_relative "list_member_problems_check"
require_relative "member_problems"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The one-member audits list-member-problems offers across maps: the changed members each may judge, joined
    # where principles share one, leaving out the principles whose records wait on an upgrade.
    class AcknowledgementsToOffer
      # maps is each map's MemberProblems; except, the principles whose records wait on an upgrade.
      #: (Array[MemberProblems], except: Array[String]) -> void
      def initialize(maps, except:)
        @maps = maps
        @except = except
        freeze
      end

      # Each set of principle ids, in id order, with the members they acknowledge together, those of principles that
      # share one joined in one acknowledgement across them. Each set holding a member last names comes after the
      # others.
      #: () -> Hash[Array[String], Array[String]]
      def together = offered.partition { |_ids, members| !members.intersect?(last) }.flatten(1).to_h

      # The acknowledgeable members whose check is this tool's own list-member-problems --short, which refuses their
      # acknowledgement while it lists a member the answer leaves out, so they are acknowledged after the others;
      # none whose set holds every member --short lists, since nothing else is to come first.
      #: () -> Array[String]
      def last
        sets = offered.values
        self_checked.select { |id| sets.find { it.include?(id) }&.then { listed_beside?(it) } }
      end

      private

      # The sets to offer: those grouped, with every set holding a member --short checks joined into one across their
      # principles, since apart each such member's check lists the other's and none could pass.
      #: () -> Hash[Array[String], Array[String]]
      def offered
        checking, others = grouped.partition { |_ids, members| members.intersect?(self_checked) }
        return grouped if checking.length < 2

        others.to_h.merge(checking.flat_map(&:first).uniq.sort => checking.flat_map(&:last).uniq)
      end

      # The members, of every map, whose check is this tool's own list-member-problems --short.
      #: () -> Array[String]
      def self_checked
        @maps.flat_map { |map| map.members.select { ListMemberProblemsCheck.of(it.check.to_s) }.map(&:id) }.uniq
      end

      # Each set of principle ids with the members they acknowledge together, in no set order.
      #: () -> Hash[Array[String], Array[String]]
      def grouped
        acknowledgeable.reduce({}) do |joined, (id, members)|
          @except.include?(id) ? joined : joining(joined, id, members)
        end
      end

      # Whether --short lists a member set leaves out: one changed, or one no audit has assessed, in a map whose
      # record waits on no upgrade.
      #: (Array[String]) -> bool
      def listed_beside?(set)
        acting = @maps.reject { @except.include?(it.principle_id) }
        acting.any? { it.never_assessed.positive? } ||
          acting.flat_map(&:entries).any? { it.fetch("state") == "changed" && !set.include?(it.fetch("id")) }
      end

      # For each map with a changed member a one-member audit may judge, the ids of those members.
      #: () -> Hash[String, Array[String]]
      def acknowledgeable
        @maps.to_h { |map| [map.principle_id, map.acknowledgeable_member_ids] }.reject { |_, ids| ids.empty? }
      end

      # groups with principle id's members joined into each group that shares one of them, as one group.
      #: (Hash[Array[String], Array[String]], String, Array[String]) -> Hash[Array[String], Array[String]]
      def joining(groups, id, members)
        joined = groups.select { |_ids, others| others.intersect?(members) }
        rest = groups.reject { |ids, _others| joined.key?(ids) }
        rest.merge([*joined.keys.flatten, id].sort => [*joined.values.flatten, *members].uniq)
      end
    end
  end
end

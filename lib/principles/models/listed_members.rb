# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The members a member's own list-member-problems check lists now, beside those one answer acknowledges: the check
    # exits 3 until that answer's record is committed, and lists none then only if it acknowledges every one.
    class ListedMembers
      # listed is each member the check lists, as its principle id and member id; acknowledging is each member the
      # answer acknowledges, the same way, across every principle it answers for; never_assessed counts, by
      # principle, the members no audit has assessed, which the check counts and no acknowledgement clears.
      #: (listed: Array[[String, String]], principle_id: String, acknowledging: Array[[String, String]],
      #|  ?never_assessed: Hash[String, Integer]) -> void
      def initialize(listed:, principle_id:, acknowledging:, never_assessed: {})
        @listed = listed
        @principle_id = principle_id
        @acknowledging = acknowledging
        @never_assessed = never_assessed
        freeze
      end

      # Whether ids, as an answer reports them, are the ids of the members listed, each once, in any order.
      #: (untyped) -> bool
      def reported?(ids) = ids.is_a?(Array) ? ids.sort == @listed.map(&:last).sort : false

      # The members listed that the answer does not acknowledge, which the check would still list: each by its id,
      # with its principle when that is another, since an id is unique only within its map; then each principle's
      # members no audit has assessed, by count.
      #: () -> Array[String]
      def unacknowledged
        listed = (@listed - @acknowledging).map do |principle, id|
          principle == @principle_id ? id : "#{id} of #{principle}"
        end
        listed + @never_assessed.map { |principle, count| never_assessed(principle, count) }
      end

      private

      # count members of principle no audit has assessed, as a refusal names them.
      #: (String, Integer) -> String
      def never_assessed(principle, count)
        "#{count} member#{"s" unless count == 1} of #{principle} no audit has assessed"
      end
    end
  end
end

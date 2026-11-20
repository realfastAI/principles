# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "principle"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The members an acknowledgement across several principles names, and which of them each principle maps:
    # every member must be mapped by one of them, and each of them must map one, or it would acknowledge nothing.
    class MembersAcrossPrinciples
      #: (Array[Principle], Array[String]) -> void
      def initialize(principles, member_ids)
        @principles = principles.uniq(&:id).sort_by(&:id) #: Array[Principle]
        @member_ids = member_ids
        freeze
      end

      # The first member none of the principles maps, or nil when each is mapped by one.
      #: () -> String?
      def unmapped = @member_ids.find { |member_id| @principles.none? { it.members.taken?(member_id) } }

      # Each principle's id, in id order, with the members it maps in the order they were named; refused for a member
      # none maps, as an unknown member of the first principle, which names a near miss, or for a principle that maps
      # none.
      #: () -> Hash[String, Array[String]]
      def by_principle
        missing = unmapped
        @principles.fetch(0).member(missing) if missing
        @member_ids.each { refuse_checked_differently(it) }
        @principles.to_h do |principle|
          mapped = @member_ids.select { principle.members.taken?(it) }
          refuse_mapping_none(principle.id) if mapped.empty?
          [principle.id, mapped]
        end
      end

      private

      # Each principle that checks member_id, by id beside the check it names.
      #: (String) -> Array[[String, String]]
      def checks_of(member_id)
        @principles.filter_map do |principle|
          check = principle.members.with_id(member_id)&.check
          [principle.id, check] if check
        end
      end

      # Refuses member_id when the principles that check it name different checks, since one check_result, which an
      # answer across them gives once, cannot report two runs: each principle acknowledges it with its own request.
      #: (String) -> void
      def refuse_checked_differently(member_id)
        checks = checks_of(member_id)
        return if checks.map(&:last).uniq.size < 2

        each = ProseList.new(checks.map { |id, check| "#{check} in #{id}" }, conjunction: "and by")
        each_own = checks.map do |id, _check|
          Error::RepairCommand.new(purpose: "To acknowledge it in #{id}", command: "start-audit", values: [id],
                                   options: ["--member", member_id])
        end
        refusal = Error.new("cannot_acknowledge",
                            "#{member_id} is checked by #{each}, and one check_result cannot report both", "")
        raise refusal.ending_with(each_own)
      end

      # Refuses principle id, which maps none of the members, so it would acknowledge nothing.
      #: (String) -> void
      def refuse_mapping_none(id)
        raise Error.new("cannot_acknowledge", "#{id} maps none of the members named: #{ProseList.new(@member_ids)}. " \
                                              "Give only the ids of principles that map one",
                        "Run #{Error::EXECUTABLE} show-principle #{id} to see the members it maps.")
      end
    end
  end
end

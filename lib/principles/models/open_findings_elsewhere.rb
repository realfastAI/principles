# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "members_elsewhere"
require_relative "open_finding"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The findings other principles' records leave open on members sharing lines with a full audit's members, read
    # once per principle: each member's mapped_elsewhere names them by id, and the request lists each once, since a
    # whole file's findings printed in full beside every passage within it.
    class OpenFindingsElsewhere
      # sharing gives, under each audited member's id, the other principles' members sharing its lines.
      #: (Hash[String, MembersElsewhere], AuditRecords) -> OpenFindingsElsewhere
      def self.of(sharing, records)
        ids = sharing.values.flat_map(&:principle_ids).uniq
        new(sharing, ids.to_h { |id| [id, records.left_open_or_none(id)] })
      end

      #: (Hash[String, MembersElsewhere], Hash[String, Array[OpenFinding]]) -> void
      def initialize(sharing, left_open_by_principle)
        @sharing = sharing
        @left_open_by_principle = left_open_by_principle
        freeze
      end

      # The other principles' members sharing the lines of the audited member member_id, each naming by id the
      # findings left open on it.
      #: (String) -> Array[Hash[String, untyped]]
      def beside(member_id) = @sharing.fetch(member_id).naming(@left_open_by_principle)

      # Whether another principle leaves a finding open on a member sharing the lines of the audited member member_id.
      #: (String) -> bool
      def open_beside?(member_id) = @sharing.fetch(member_id).open_among(@left_open_by_principle).any?

      # Each finding left open on any of them, once, with its principle, and what its evidence's lines are beside
      # lines, this audit's members, where locate finds each item now: a finding is the same one when its
      # principle and id are.
      #: (AuditedMemberLines) { (Locator) -> LocatedText } -> Array[Hash[String, untyped]]
      def listed(lines, &)
        @sharing.values.flat_map { |members| members.open_among(@left_open_by_principle) }
                .uniq { |finding| [finding.principle_id, finding.id] }
                .map { |finding| finding.listed_elsewhere(lines, &) }
      end
    end
  end
end

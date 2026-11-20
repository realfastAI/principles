# typed: strict
# frozen_string_literal: true

require_relative "acknowledgements"
require_relative "request_id"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Members that several principles map, acknowledged for each of them in one request and one answer: one
    # judgement per member, read as each principle's own acknowledgement of it, so one edit is judged once, not once
    # per principle.
    class AcknowledgementsAcross
      # by_principle holds each principle's acknowledgement of the members it maps, under its id, and checked the ids
      # of the members each one gives a check, under its id.
      #: (Hash[String, Acknowledgements], ?checked: Hash[String, Array[String]]) -> void
      def initialize(by_principle, checked: {})
        @by_principle = by_principle.sort.to_h #: Hash[String, Acknowledgements]
        @checked = checked
        freeze
      end

      # The request's id: each principle's own request id for its members, sorted, under the first principle's id, so
      # it depends on which principles and members it asks about, not on the order they were named in.
      #: () -> RequestId
      def request_id
        RequestId.for(principle_id: @by_principle.keys.fetch(0), phase: Acknowledgements::PHASE,
                      parts: @by_principle.values.map { it.request_id.to_s }.sort)
      end

      # Every member some principle acknowledges, each once, in the order the principles name them.
      #: () -> Array[String]
      def member_ids = @by_principle.values.flat_map(&:member_ids).uniq

      # The members it acknowledges for every principle, each as its principle id and member id, which a member's own
      # list-member-problems check may list beside its own principle's.
      #: () -> Array[[String, String]]
      def acknowledging = @by_principle.values.flat_map(&:acknowledging)

      # Each principle's record with its members' baselines moved, once the answer holds an entry for each member and
      # no other: accept is given each principle's id, its acknowledgements and the answer as one to its members
      # alone, and gives its record, or refuses the whole answer, so no record is written unless each is accepted. A
      # member's check_result reports one run of its check, which answers each principle that checks the member, and
      # is left out of the answer to a principle that does not.
      #: (untyped) { (String, Acknowledgements, untyped) -> AuditRecord } -> Array[AuditRecord]
      def accepted(answer, &accept)
        entries = answer.fetch("members")
        refusal = Acknowledgements.unmatched(missing: member_ids - entries.keys, extra: entries.keys - member_ids)
        raise refusal if refusal

        @by_principle.map do |id, several|
          accept.call(id, several, answer.merge("members" => entries_for(id, entries.slice(*several.member_ids))))
        end
      end

      private

      # entries as principle id reads them: a member's check_result left out where id does not check the member.
      #: (String, Hash[String, untyped]) -> Hash[String, untyped]
      def entries_for(id, entries)
        checked = @checked.fetch(id, [])
        entries.to_h do |member_id, entry|
          [member_id, checked.include?(member_id) ? entry : entry.except("check_result")]
        end
      end
    end
  end
end

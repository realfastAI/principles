# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "audit_record"
require_relative "request_id"
require_relative "sent_answer"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Several members of one principle acknowledged in one request and one answer: each member's entry is
    # judged as its own one-member answer would be, and the answer is accepted for every member, in one record, or
    # refused for all, so no baseline moves unless each does.
    class Acknowledgements
      PHASE = "acknowledgements"

      # The JSON pointer to member_id's entry in an answer's members.
      #: (String) -> String
      def self.entry_pointer(member_id) = "/members/#{member_id.gsub("~", "~0").gsub("/", "~1")}"

      # The refusal of an answer whose members leave out each of missing or answer each of extra, which no member of
      # it is acknowledged under, named_by the basis field that names its members; nil when it does neither.
      #: (missing: Array[String], extra: Array[String], ?named_by: String) -> Error?
      def self.unmatched(missing:, extra:, named_by: "basis.member_ids")
        fields = missing.map { problem(it, "is required, since #{named_by} names it") } +
                 extra.map { problem(it, "is not a member #{named_by} names") }
        return if fields.empty?

        Error.new("invalid_answer", "#{SentAnswer::NAMED} does not answer each member it names, so no member is " \
                                    "acknowledged", SentAnswer::REPAIR, fields:)
      end

      # The problem with the answer's entry for member_id, at its JSON pointer.
      #: (String, String) -> Hash[String, String]
      def self.problem(member_id, text) = { "pointer" => entry_pointer(member_id), "problem" => text }
      private_class_method :problem

      # What the block gives for member_id's entry, a refusal of a field in it pointing at that field in the entry,
      # since a member's acknowledgement points from the entry's root, for one member's answer too.
      #: (String) { () -> AuditRecord } -> AuditRecord
      def self.in_entry(member_id, &)
        yield
      rescue Error => e
        fields = e.payload["fields"]
        raise unless fields

        entry = Acknowledgements.entry_pointer(member_id)
        raise e.including("fields" => fields.map { it.merge("pointer" => entry + it.fetch("pointer")) })
      end

      # The members as members names them, each id beside its one-member request's id, in the order named; refused
      # when one is named twice, which the answer would then judge once.
      #: (principle_id: String, members: Array[[String, RequestId]]) -> Acknowledgements
      def self.of(principle_id:, members:)
        ids = members.map(&:first)
        twice = ids.find { |id| ids.count(id) > 1 }
        if twice
          raise Error.new("invalid_answer", "#{SentAnswer::NAMED}'s basis names #{twice} twice", SentAnswer::REPAIR,
                          fields: [{ "pointer" => "/basis/member_ids", "problem" => "names #{twice} twice" }])
        end

        new(principle_id:, requests: members.to_h)
      end

      # requests holds each member's one-member request id under the member's id, in the order they were named.
      #: (principle_id: String, requests: Hash[String, RequestId]) -> void
      def initialize(principle_id:, requests:)
        @principle_id = principle_id
        @requests = requests
        freeze
      end

      # The members it acknowledges, in the order they were named.
      #: () -> Array[String]
      def member_ids = @requests.keys

      # The members it acknowledges, each as its principle id and member id, as a member's own list-member-problems
      # check lists them.
      #: () -> Array[[String, String]]
      def acknowledging = member_ids.map { [@principle_id, it] }

      # The request's id: each member's one-member request id, sorted, so it depends on which members it asks
      # about and on everything each of their requests depends on, not on the order they were named in.
      #: () -> RequestId
      def request_id
        RequestId.for(principle_id: @principle_id, phase: PHASE, parts: @requests.values.map(&:to_s).sort)
      end

      # The record with every member's baseline moved, once the answer holds an entry for each member and no other:
      # accept is given each member's id, its entry and the record the members before it changed, nil for the first,
      # and gives the record with that member's acknowledgement in it too, or refuses the whole answer.
      #: (untyped) { (String, untyped, AuditRecord?) -> AuditRecord } -> AuditRecord
      def accepted(answer, &accept)
        entries = answer.fetch("members")
        refuse_unmatched(entries.keys)
        ids = @requests.keys
        first = ids.fetch(0)
        accepted_first = Acknowledgements.in_entry(first) { accept.call(first, entries.fetch(first), nil) }
        ids.drop(1).reduce(accepted_first) do |record, id|
          Acknowledgements.in_entry(id) { accept.call(id, entries.fetch(id), record) }
        end
      end

      private

      # Refuses the answer whole unless its members hold an entry for each member its basis names, and for no other.
      #: (Array[String]) -> void
      def refuse_unmatched(answered)
        refusal = Acknowledgements.unmatched(missing: @requests.keys - answered, extra: answered - @requests.keys)
        raise refusal if refusal
      end
    end
  end
end

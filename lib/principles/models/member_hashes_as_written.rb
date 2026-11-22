# typed: strict
# frozen_string_literal: true

require_relative "recorded_entry"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The member hashes an audit record holds, read from a record a later copy wrote that this copy's schema refuses,
    # for list-member-problems to compare its members with, read-only. Only those fields are read, each entry
    # kept only when its hash is text, so nothing else of a shape this copy does not know travels; a member left out
    # is compared with the commit that mapped it instead.
    class MemberHashesAsWritten
      # fields is the record as its file holds it, or anything else JSON may give.
      #: (untyped) -> void
      def initialize(fields)
        members = fields["members"] if fields.is_a?(Hash)
        @by_key = (members.is_a?(Hash) ? kept(members) : {}).freeze #: Hash[String, String]
        freeze
      end

      # Each member's hash by the key it was recorded under, as RecordedMembers#hashes gives a readable one.
      #: Hash[String, String]
      attr_reader :by_key

      private

      # Each entry whose hash is text and whose key, if it keeps one, is text too, by its key as RecordedEntry#key
      # gives it.
      #: (Hash[untyped, untyped]) -> Hash[String, String]
      def kept(members)
        members.each_with_object({}) do |(id, entry), kept|
          kept[RecordedEntry.new(id, entry).key] = entry["sha256"] if readable?(entry)
        end
      end

      # Whether entry holds its hash, and any key it keeps, as text, the shape a readable record's schema requires.
      #: (untyped) -> bool
      def readable?(entry)
        entry.is_a?(Hash) && [entry["sha256"], entry["key"]] in [String, String | nil]
      end
    end
  end
end

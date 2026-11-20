# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The member hashes a principle's audit record holds, by key, which its members now are compared with, and
    # whether a later copy wrote that record, so its audits wait on an upgrade and the comparison is read-only.
    # A principle with no record holds none.
    class RecordedHashes
      #: (Hash[String, String], ?waiting: bool) -> void
      def initialize(by_key, waiting: false)
        @by_key = by_key.freeze #: Hash[String, String]
        @waiting = waiting #: bool
        freeze
      end

      # The hash the record holds for the member known by key, or nil when it holds none.
      #: (String) -> String?
      def hash_for(key) = @by_key[key]

      # Whether the record holds no hash, as for a principle with no record.
      #: () -> bool
      def empty? = @by_key.empty?

      # Whether a later copy wrote the record these hashes come from.
      #: () -> bool
      def waiting? = @waiting

      # Whether the member known by key, whose hash is now sha, has the text the record assessed: current or changed,
      # and unassessed when the record holds no hash for it.
      #: (String, String) -> String
      def freshness(key, sha)
        recorded = @by_key[key]
        return "unassessed" unless recorded

        recorded == sha ? "current" : "changed"
      end

      NONE = new({}) #: RecordedHashes
    end
  end
end

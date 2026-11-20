# typed: strict
# frozen_string_literal: true

require_relative "accepted_loading"
require_relative "member"
require_relative "recorded_entry"
require_relative "recorded_hashes"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The members an audit record assessed: each filed under the id it had then, with its key beside it when the
    # two differ, holding its hash then, the result reported for its check, its accepted loading decision
    # and the acknowledgements made for it since. Callers reach them through AuditRecord#members.
    class RecordedMembers
      #: (Hash[String, untyped]) -> void
      def initialize(entries)
        @entries = entries
        freeze
      end

      # The entries as the record's file holds them.
      #: () -> Hash[String, untyped]
      def to_h = @entries

      # The entries without when each assessment was made, or when a sighting it gave no date for was dated, which a
      # record made again from the same answer dates anew.
      #: () -> Hash[String, untyped]
      def undated
        @entries.transform_values do |entry|
          kept = entry["assessment"]
          kept ? entry.merge("assessment" => kept.except("assessed_at", "observed_at")) : entry
        end
      end

      # The path of each file an assessment kept here cites as evidence, carried forward or made now.
      #: () -> Array[String]
      def cited_paths
        @entries.flat_map { |id, entry| RecordedEntry.new(id, entry).cited_paths }.uniq
      end

      # Whether the text of the member known by key, whose hash is now sha, is the text the record assessed.
      #: (String, String) -> String
      def freshness(key, sha) = hashes.freshness(key, sha)

      # The hashes the record assessed, which a member now is compared with.
      #: () -> RecordedHashes
      def hashes = RecordedHashes.new(hashes_by_key)

      # Each hash the record assessed, by the key of the member it belongs to.
      #: () -> Hash[String, String]
      def hashes_by_key
        @entries.to_h { |id, entry| [RecordedEntry.new(id, entry).key, entry.fetch("sha256")] }
      end

      # The hash the record assessed for the member known by key, or nil when it assessed no such member.
      #: (String) -> String?
      def hash_for(key)
        entry_for(key)&.fetch("sha256")
      end

      # The check the record's audit was given an exit status for, for the member known by key: nil when the
      # member had no check then, or its check was reported as not run, so no audit has run it.
      #: (String) -> String?
      def check_run_for(key)
        result = entry_for(key)&.fetch("check_result", nil) or return nil
        result.key?("exit_status") ? result.fetch("command") : nil
      end

      # How check, the map's check now for the member known by key, stands to the one the record's audit ran:
      # :unchanged when it ran this same command, or none for a member that has none; :removed when it ran one the
      # member no longer has; :changed when it ran another; :not_run when it was told this one could not be run; :new
      # when it reported none. The one owner of that comparison, which a full audit's template and a
      # one-member audit both ask.
      #: (String, String?) -> Symbol
      def check_since(key, check)
        ran = check_run_for(key)
        return :unchanged if ran == check
        return :removed unless check
        return :changed if ran

        entry_for(key)&.dig("check_result", "command") == check ? :not_run : :new
      end

      # What the review of that run rested on, for the member known by key, as the record keeps it: its review_basis
      # and any review_basis_since, or nothing when the record ran no check for it or kept no line.
      #: (String) -> Hash[String, untyped]
      def check_review_as_kept(key)
        return {} unless check_run_for(key)

        entry_for(key)&.fetch("check_result")&.slice("review_basis", "review_basis_since") || {}
      end

      # Each member's accepted loading decision, by its id now, found by the key it keeps through moves.
      #: (PrincipleMembers) -> Hash[String, AcceptedLoading]
      def loading_accepted(members)
        members.to_h do |member|
          entry = entry_for(member.key)
          [member.id, entry&.key?("loading_accepted") ? AcceptedLoading.new(entry) : nil]
        end.compact
      end

      # The acknowledgements made for the member known by key since the record's audit, oldest first.
      #: (String) -> Array[Hash[String, untyped]]
      def acknowledgements_for(key)
        entry_for(key)&.fetch("acknowledgements", nil) || []
      end

      # The member acknowledged most recently and when, as [id, acknowledged_at], or nil when none was since the
      # record's audit. The times compare as text, which orders them only because every writer gives UTC in
      # ISO 8601.
      #: () -> [String, String]?
      def latest_acknowledgement
        @entries.flat_map do |id, entry|
          (entry["acknowledgements"] || []).map { |change| [id, change.fetch("acknowledged_at")] }
        end.max_by(&:last)
      end

      # These entries with the member known by key moved to change's to_sha256, and change kept beside it, with
      # check_result, when given, in place of the result it kept.
      #: (String, Hash[String, untyped], ?check_result: Hash[String, untyped]?) -> RecordedMembers
      def acknowledged(key, change, check_result: nil)
        RecordedMembers.new(@entries.to_h do |id, entry|
          next [id, entry] unless RecordedEntry.new(id, entry).key == key

          result = check_result ? { "check_result" => check_result } : {}
          [id, entry.merge("sha256" => change.fetch("to_sha256"), **result,
                           "acknowledgements" => [*entry["acknowledgements"], change])]
        end)
      end

      # The key of the member filed under id: its stored key when it had moved, or else id.
      #: (String) -> String
      def key_of(id)
        RecordedEntry.new(id, @entries.fetch(id, {})).key
      end

      # The entry of the member known by key, under the id it was filed under, or nil when the record has none.
      #: (String) -> RecordedEntry?
      def recorded(key)
        id, entry = @entries.find { |filed, each| RecordedEntry.new(filed, each).key == key }
        RecordedEntry.new(id, entry) if id && entry
      end

      # These entries with each assessment an answer carried forward, marked {"carried_forward": true}, replaced by
      # the one last kept for the same member, so the record keeps it with its first date.
      #: (RecordedMembers?) -> RecordedMembers
      def carrying(last)
        RecordedMembers.new(@entries.to_h do |id, entry|
          next [id, entry] unless entry.dig("assessment", "carried_forward")

          [id, entry.merge("assessment" => last&.recorded(RecordedEntry.new(id, entry).key)&.assessment).compact]
        end)
      end

      private

      # The entry for the member known by key: filed under the id it had then, with its key beside it when the
      # two differ.
      #: (String) -> Hash[String, untyped]?
      def entry_for(key)
        @entries.find { |id, entry| RecordedEntry.new(id, entry).key == key }&.last
      end
    end
  end
end

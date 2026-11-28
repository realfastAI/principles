# typed: strict
# frozen_string_literal: true

require_relative "assessment_report"
require_relative "json_digest"
require_relative "principle"
require_relative "stale_request"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What an audit began from: the principle and its map, the commit it was based on (nil outside git) and
    # each member's hash then, and what the assessment reported beyond its findings, as its AssessmentReport holds it.
    class AuditStart
      #: String?
      attr_reader :base
      #: Hash[String, String]
      attr_reader :before

      # What the assessment reported beyond its findings, such as each member's record entry fields.
      #: AssessmentReport
      attr_reader :reported

      # The map of the principle the audit is of.
      #: Principle
      attr_reader :map

      #: (map: Principle, base: String?, before: Hash[String, String], ?reported: AssessmentReport) -> void
      def initialize(map:, base:, before:, reported: AssessmentReport::NONE)
        @map = map
        @base = base
        @before = before
        @reported = reported
        freeze
      end

      # The principle the audit is of, as its map names it.
      #: () -> String
      def id = @map.id

      # Each member's entry in the record, by id, from its hash in members: the hash, its key when it has moved,
      # and what the assessment reported for it, if anything, its assessment kept as made at assessed_at. A member
      # added during the audit has no entry, since no assessment read it: the record gives it no baseline, so the
      # next audit judges it (T69).
      #: (Hash[String, String], assessed_at: String) -> Hash[String, Hash[String, untyped]]
      def recorded(members, assessed_at:)
        keys = @map.members.moved_keys
        members.select { |id, _| began_with?(id) }.to_h do |id, sha|
          entry = { "sha256" => sha }.merge(keys.key?(id) ? { "key" => keys[id] } : {})
          [id, with_assessment(entry.merge(@reported.entry_fields_of(id)), assessed_at, changed: @before[id] != sha)]
        end
      end

      private

      # Whether the audit began with member id, rather than a correction adding it (T69).
      #: (String) -> bool
      def began_with?(id) = @before.key?(id)

      # The entry with its assessment dated assessed_at, and an observed sighting the answer gave no observed_at for
      # dated then too, or a carried one left for completion to fill; when the member changed during the
      # audit, as a fix in its correction changes it, no assessment read the text it is recorded at, so it keeps none
      # and says why.
      #: (Hash[String, untyped], String, changed: bool) -> Hash[String, untyped]
      def with_assessment(entry, assessed_at, changed:)
        kept = entry["assessment"] or return entry
        return entry.except("assessment").merge("changed_during_last_audit" => true) if changed
        return entry if kept["carried_forward"]

        seen = kept["delivery"] == "observed" ? assessed_at : nil
        entry.merge("assessment" => { "assessed_at" => assessed_at, "observed_at" => seen }.compact.merge(kept))
      end

      public

      # A digest of what this audit's assessments answered: the principle's description and question, the question
      # this tool asked. When either changes, the next full audit carries no assessment forward.
      #: (String) -> String
      def judged_against(question) = JsonDigest.new("description" => @map.description, "question" => question).to_s

      # The map's version: the digest of its JSON, so any change to it gives a new version.
      #: () -> String
      def map_version = @map.version

      # The members in now that the audit did not begin with, as a correction adds a member a finding said was
      # missing (T69).
      #: (now: Hash[String, String]) -> Array[String]
      def added(now:) = now.keys.reject { |id| began_with?(id) }

      # Refuses an answer to this audit as stale once the text of a plugin member in now differs from the text the
      # audit began with: an update to the installed plugin, which no fix can claim.
      #: (now: Hash[String, String]) -> void
      def check_plugin_members_unchanged(now:)
        updated = changed(now:).select { @map.members.with_id(it)&.plugin_reference }
        raise StaleRequest.plugin_updated(id, updated) if updated.any?
      end

      # The members whose hash in now differs from their hash when the audit began.
      #: (now: Hash[String, String]) -> Array[String]
      def changed(now:)
        now.reject { |member, sha| @before[member] == sha }.keys
      end
    end
  end
end

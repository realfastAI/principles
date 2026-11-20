# typed: strict
# frozen_string_literal: true

require_relative "locator"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One member's entry in a completed audit record, filed under the id the member had then: its hash, any
    # acknowledgements since, and the assessment that audit kept for it, with what it was judged on.
    class RecordedEntry
      #: (String, Hash[String, untyped]) -> void
      def initialize(filed_id, entry)
        @filed_id = filed_id
        @entry = entry
        freeze
      end

      # The key the record knows the member by: the key kept beside its entry when it differs from the id it was
      # filed under, else that id. The one owner of that rule, which MemberHashesAsWritten reads a newer record by
      # too.
      #: () -> String
      def key = @entry["key"] || @filed_id

      # The assessment the audit kept, with when it was made and what it was judged on; nil when it kept none.
      #: () -> Hash[String, untyped]?
      def assessment = @entry["assessment"]

      # The path of each file the kept assessment cites as evidence; none when it kept none.
      #: () -> Array[String]
      def cited_paths = (assessment&.fetch("evidence", nil) || []).map { it.fetch("path") }

      # Each of finding_ids the kept assessment's text names as a whole word, in its assessment or observation; none
      # when it kept none. Ids repeat across records, so naming one says only that the text may cite it.
      #: (Array[String]) -> Array[String]
      def naming(finding_ids)
        kept = assessment or return []
        text = kept.values_at("assessment", "observation").compact.join("\n")
        finding_ids.select { text.match?(/(?<![[:alnum:]_])#{Regexp.escape(it)}(?![[:alnum:]_])/) }
      end

      # The kept assessment as the next full audit shows it carried forward, an observed delivery's sighting dated
      # beside it, with whether any evidence it cited changed since, which the block says from each evidence
      # item's hash then.
      #: () { (Locator, String) -> bool } -> Hash[String, untyped]
      def carried_forward(&changed)
        kept = assessment || {}
        evidence = kept.fetch("evidence").zip(kept.fetch("evidence_sha256"))
        kept.slice("assessment", "delivery").merge(sighting(kept), kept.slice("observation", "evidence", "assessed_at"))
            .merge("evidence_changed" => evidence.any? { |each, sha| changed.call(Locator.new(each), sha) })
      end

      # When the sighting the kept assessment observed was, if observation repeats its observation word for word:
      # its observed_at, or for a record from before sightings were dated, its assessed_at. Nil otherwise.
      #: (String) -> String?
      def repeated_sighting(observation)
        kept = assessment or return nil
        sighted_at(kept) if kept["observation"] == observation
      end

      # The id the member had when the audit recorded it, when that differs from id, its id now.
      #: (String) -> String?
      def moved_from(id) = (@filed_id unless @filed_id == id)

      # Why the member, now id with its text hashing to sha256 and judged on grounds, must be judged again, or nil
      # when its kept assessment still describes it: the same text the audit judged, under the same id, map entry
      # and loads. An acknowledged edit is judged again, unless it was undone.
      #: (id: String, sha256: String?, grounds: Hash[String, String]) -> String?
      def judge_because(id:, sha256:, grounds:)
        return "changed_during_last_audit" if @entry["changed_during_last_audit"]

        kept = assessment or return "not_assessed_before"
        return text_changed if audited_sha256 != sha256
        return "moved" if moved_from(id)
        return "role_or_check_changed" if kept["entry_sha256"] != grounds["entry_sha256"]

        "loads_changed" if kept["loads_sha256"] != grounds["loads_sha256"]
      end

      private

      # When kept's observed delivery was seen, as shown beside it: its observed_at, or for a record from before
      # sightings were dated, its assessed_at, saying so. Empty for a delivery not observed.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def sighting(kept)
        return {} unless kept["delivery"] == "observed"

        { "observed_at" => sighted_at(kept), "observed_at_from_assessed_at" => (true unless kept["observed_at"]) }
          .compact
      end

      # When the sighting kept was: its observed_at, or its assessed_at in a record from before sightings were dated.
      #: (Hash[String, untyped]) -> String?
      def sighted_at(kept) = kept["observed_at"] || kept["assessed_at"]

      # The hash of the text the audit judged: the first acknowledgement's starting point when the member has been
      # acknowledged since, since an acknowledgement moves the recorded hash, or else the recorded hash.
      #: () -> String
      def audited_sha256 = acknowledgements.first&.fetch("from_sha256") || @entry.fetch("sha256")

      #: () -> String
      def text_changed = acknowledgements.empty? ? "text_changed" : "acknowledged_since_last_audit"

      #: () -> Array[Hash[String, untyped]]
      def acknowledgements = @entry.fetch("acknowledgements", [])
    end
  end
end

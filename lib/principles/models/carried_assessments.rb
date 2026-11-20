# typed: strict
# frozen_string_literal: true

require_relative "audit_record"
require_relative "member"
require_relative "member_grounds"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Which members a full audit carries forward the last full audit's assessment of, and why it asks the agent to
    # judge each other one. A member is carried only when the last completed record kept its assessment
    # and judged it against the same description and question, and its text, id, map entry and loads are as that
    # audit judged them. Each test compares stored values, so it is this tool's to make; whether the set still
    # holds, and whether to re-judge a carried member, is the agent's.
    class CarriedAssessments
      # record is the principle's audit record now, if any; members are the map's members now, with their hashes in
      # now and their grounds; judged_against digests the description and question this audit asks.
      #: (AuditRecord?, members: PrincipleMembers, judged_against: String, now: Hash[String, String],
      #|  grounds: MemberGrounds) -> void
      def initialize(record, members:, judged_against:, now:, grounds:)
        @last = record&.last_completed #: AuditRecord?
        @members = members
        @judged_against = judged_against
        @now = now
        @grounds = grounds
        freeze
      end

      # Why the member id must be judged again, or nil when its last assessment is carried forward. A record from
      # before assessments were kept assessed each member it recorded, but kept none to carry.
      #: (String) -> String?
      def judge_because(id)
        last = @last or return "not_assessed_before"
        entry = recorded(id)
        return reason_in_record_before_assessments_were_kept(entry) unless last.kept_assessments?
        return "description_or_question_changed" unless last.judged_against?(@judged_against)

        entry ? entry.judge_because(id: id, sha256: @now[id], grounds: @grounds.of(id)) : "not_assessed_before"
      end

      # Whether the member id's last assessment is carried forward.
      #: (String) -> bool
      def carried?(id) = judge_because(id).nil?

      # What the request shows beside the member id: the assessment carried forward, with whether any evidence it
      # cited changed since, which the block says from each evidence item's hash then; or why it is judged again, and
      # where it was if it moved.
      #: (String) { (Locator, String) -> bool } -> Hash[String, untyped]
      def shown(id, &)
        reason = judge_because(id)
        return { "judge_because" => reason, "moved_from" => recorded(id)&.moved_from(id) }.compact if reason

        entry = recorded(id) or return {}
        { "carried_forward" => entry.carried_forward(&) }
      end

      # When the last full audit's sighting of the member id was, if a fresh observation repeats that audit's word for
      # word; nil when it does not, or there was none. Whether the sighting is the same is the agent's to say.
      #: (String, String) -> String?
      def repeated_sighting(id, observation) = recorded(id)&.repeated_sighting(observation)

      # Each member answer carries forward whose kept assessment names a prior finding answer decides other than
      # still_holds, with those ids, for the agent to judge whether that assessment still holds. Read from an answer
      # already checked.
      #: (Hash[String, untyped]) -> Array[Hash[String, untyped]]
      def naming_decided(answer)
        decided = (answer["prior_finding_decisions"] || []).reject { it["decision"] == "still_holds" }
                                                           .map { it.fetch("finding_id") }
        return [] if decided.empty?

        answer.fetch("member_assessments").select { it["carried_forward"] }.filter_map do |entry|
          ids = recorded(entry.fetch("member_id"))&.naming(decided) || []
          { "member_id" => entry.fetch("member_id"), "finding_ids" => ids } unless ids.empty?
        end
      end

      private

      # Why a member of a record from before assessments were kept is judged again: that audit assessed it, if the
      # record holds its entry, but kept no assessment to carry.
      #: (RecordedEntry?) -> String
      def reason_in_record_before_assessments_were_kept(entry)
        entry ? "assessed_before_assessments_were_kept" : "not_assessed_before"
      end

      #: (String) -> RecordedEntry?
      def recorded(id) = @last&.members&.recorded(@members.found(id).key)
    end
  end
end

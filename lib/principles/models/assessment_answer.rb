# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "answer_fields"
require_relative "answer_place"
require_relative "loads_to_check"
require_relative "member_assessments"
require_relative "misspelt_member_id"
require_relative "new_findings"
require_relative "recent_decision"
require_relative "record_judged_against"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # An agent's answer to an assessment request: one assessment per member, an assessment of the set, a
    # recent decision under it, and findings. The block locates each piece of evidence in the project and
    # refuses one that does not resolve. members are the audited members, each checked one's assessment reporting
    # its check's result; judged_against is the principle's record as it stands, which lists the members
    # whose loading it must decide and the assessments it may carry; answered_at is when it came, which
    # no sighting it reports is after.
    class AssessmentAnswer
      # The text the template prints in collective_assessment, which an answer may not send back unchanged.
      COLLECTIVE_PLACEHOLDER = "How the members reinforce the principle, and any contradiction or missing " \
                               "connection." #: String
      # How a field --as template's answer leaves as printed is read, printed once at the template's head in
      # left_as_printed_rule, where an agent filling it reads, which the answer may send back and this tool ignores.
      LEFT_AS_PRINTED_RULE = "A field left as printed is read as omitted, as is this one: one saying \"else kept\" " \
                             "keeps what it had, and null drops it where offered. A sighting sets delivery to " \
                             "\"observed\" and adds observation, and observed_at for one before this audit." #: String

      #: (untyped, PrincipleMembers, answered_at: String, ?judged_against: RecordJudgedAgainst?)
      #|   { (Locator) -> LocatedText } -> void
      def initialize(response, members, answered_at:, judged_against: nil, &locate)
        @response = response
        @members = members
        @answered_at = answered_at
        @judged_against = judged_against
        @loads = judged_against&.loads #: LoadsToCheck?
        @locate = locate #: ^(Locator) -> LocatedText
        @fields = AnswerFields.new(locate) #: AnswerFields
      end

      # The answer's findings, once every member assessment, the collective assessment, the recent
      # decision and each finding have been checked.
      #: () -> Array[untyped]
      def findings
        member_assessments.check
        @fields.text(@response["collective_assessment"], "collective_assessment")
        recent_decision.check(@fields)
        checked_findings
      end

      # The result reported for each checked member's check, by member id, once each has been checked.
      #: () -> Hash[String, Hash[String, untyped]]
      def check_results = member_assessments.check_results

      # By member id, the fields this answer reports for each member's record entry: its assessment, which the next
      # full audit may carry forward, its check's result and its accepted loading decision, once
      # each listed member's is checked against loads.
      #: () -> Hash[String, Hash[String, untyped]]
      def entry_fields
        checked = check_results.transform_values do |result|
          { "check_result" => result }
        end #: Hash[String, Hash[String, untyped]]
        accepted = (@loads&.decided(@response["loading_decisions"]) || {}).transform_values do |kept|
          { "loading_accepted" => kept }
        end
        reported = checked.merge(accepted) { |_id, check, loading| check.merge(loading) }
        member_assessments.kept(&@locate).merge(reported) { |_id, assessment, fields| assessment.merge(fields) }
      end

      # The paths the recent decision's evidence cites, which the record does not keep but a completed audit asks to
      # commit when they differ from HEAD; none when the decision was unavailable.
      #: () -> Array[String]
      def recent_decision_paths
        recent_decision.paths
      end

      private

      #: () -> MemberAssessments
      def member_assessments
        MemberAssessments.new(@response["member_assessments"], @members, fields: @fields,
                                                                         judged_against: @judged_against,
                                                                         answered_at: @answered_at)
      end

      #: () -> RecentDecision
      def recent_decision = RecentDecision.new(@response.fetch("recent_decision"))

      #: () -> Array[untyped]
      def checked_findings
        findings = NewFindings.new(@fields.array(@response.fetch("findings", []), "findings")).raised
        finding_ids = findings.each_with_index.map { |finding, index| finding_id(finding, index) }
        unless finding_ids.uniq == finding_ids
          raise Error.new("duplicate_finding", "Finding ids repeat",
                          "Give each finding a unique id.")
        end

        findings
      end

      # The id of finding, once its fields, members and evidence have been checked.
      #: (untyped, Integer) -> untyped
      def finding_id(finding, index)
        @fields.text(finding["id"], "finding.id")
        %w[problem consequence proposed_action].each { |field| @fields.text(finding[field], "finding.#{field}") }
        affected_members(finding)
        place = AnswerPlace.new("/findings/#{index}", "Finding #{finding["id"]}")
        @fields.evidence(finding["evidence"], place.child("evidence"))
        finding.fetch("id")
      end

      # Refuses a finding that names no member, or one the map does not have.
      #: (untyped) -> void
      def affected_members(finding)
        affected = @fields.array(finding["member_ids"], "finding.member_ids")
        ids = @members.ids
        return unless affected.empty? || (affected - ids).any?

        raise Error.new("unknown_member", "Finding #{finding["id"]} names unknown or no members",
                        [*near_misses(affected - ids), "Use one or more of #{ids.join(", ")}."].join(" "))
      end

      # A hint for each unmapped id that differs from a mapped one only in punctuation, case or spacing.
      #: (Array[untyped]) -> Array[String]
      def near_misses(unknown) = unknown.grep(String).filter_map { |id| MisspeltMemberId.new(id).hint(@members.ids) }
    end
  end
end

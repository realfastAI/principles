# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "principle"
require_relative "declared_map_changes"
require_relative "request_id"
require_relative "correction_basis"
require_relative "assessment_basis"
require_relative "assessment_answer"
require_relative "audit_start"
require_relative "assessment_report"
require_relative "loads_to_check"
require_relative "member_grounds"
require_relative "carried_assessments"
require_relative "prior_findings"
require_relative "decided_prior_findings"
require_relative "disposition"
require_relative "stale_request"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One principle's audit as its map and members are now. Nothing about a request is stored: each
    # request id digests what the request depends on, so an answer is refused when what it was asked about
    # has changed since. A correction is based on the map's version and each finding's members, never on
    # the agent's prose.
    class Audit
      #: Principle
      attr_reader :map
      # Each member's hash now.
      #: Hash[String, String]
      attr_reader :now

      #: (map: Principle, now: Hash[String, String]) -> void
      def initialize(map:, now:)
        @map = map
        @now = now
      end

      # The principle audited, as its map names it.
      #: () -> String
      def id = @map.id

      #: () -> String
      def map_version = @map.version

      # The id of the assessment request printed with basis: its base commit, nil outside git, and the last
      # completed record's revision, so an answer cannot point the request at a later record.
      # prior is what PriorFindings#digested gives, empty when the last audit left no finding to decide;
      # loads is what LoadsToCheck#listed gives, nil when the activation lists nothing to check.
      #: (AssessmentBasis, ?Array[Hash[String, untyped]], ?Hash[String, untyped]?) -> RequestId
      def assessment_id(basis, prior = [], loads = nil)
        parts = [map_version, basis.digested, @now]
        parts = [*parts, prior] unless prior.empty?
        parts = [*parts, { "loads_to_check" => loads }] if loads
        RequestId.for(principle_id: id, phase: "assessment", parts: parts)
      end

      # Refuses an assessment unless request_id is the one printed with basis for the map and members as they are
      # now, and, in git, the members are as its base holds them (committed).
      # It returns the findings the last audit, whose record is given, left for this one to decide; loads is
      # what the audit lists to check now, so a change to what lists a member to check makes the request stale.
      #: (RequestId, basis: AssessmentBasis, committed: Hash[String, String]?, record: AuditRecord?,
      #|  loads: LoadsToCheck) -> PriorFindings
      def check_assessment_request(request_id, basis:, committed:, record:, loads:)
        prior = prior_findings(record)
        now_id = assessment_id(basis, prior.digested, loads.listed)
        return prior if now_id == request_id && (basis.base.nil? || committed == @now)

        raise StaleRequest.new(id, changed_since(committed), correction_open: record&.open? || false).refusal
      end

      # The answer to this audit's assessment request, checked against each member, each member's check
      # and each member the listing names to check against the activation; the block locates each piece of
      # evidence, giving where it is and the hash of its text.
      # judged_against is the principle's record as it stands, which says which members' last assessments the
      # answer may carry forward; answered_at is when the answer came, which no sighting it reports is after.
      #: (untyped, RecordJudgedAgainst, String) { (Locator) -> Hash[String, untyped] }
      #|  -> AssessmentAnswer
      def assessment(response, judged_against, answered_at, &)
        AssessmentAnswer.new(response, members, answered_at: answered_at, judged_against: judged_against, &)
      end

      # A digest of what this audit's assessments answer: its description and question.
      #: (String) -> String
      def judged_against(question) = started(nil, {}).judged_against(question)

      # What this audit began from: base (nil outside git), each member's hash then and what the assessment reported
      # beyond its findings.
      #: (String?, Hash[String, String], ?AssessmentReport) -> AuditStart
      def started(base, before, reported = AssessmentReport::NONE)
        AuditStart.new(map: @map, base: base, before: before, reported: reported)
      end

      # What an audit answered by assessed began from: base, each member's hash now, and what the answer reported
      # beyond its findings, each assessment with the grounds it was judged on.
      #: (String?, AssessmentAnswer, MemberGrounds) -> AuditStart
      def assessed_start(base, assessed, grounds)
        started(base, @now, AssessmentReport.answered(assessed, grounds))
      end

      # What the audit a correction's basis names began from: its base commit, each member's hash then
      # (before), and the assessment's report record keeps, under the ids of any moved members. The record is
      # the open one the basis was printed with, or a completed one, which only an identical retry may complete
      # again; none, or another open one, refuses the correction as stale.
      #: (CorrectionBasis, Hash[String, String], MemberMoves, AuditRecord?) -> AuditStart
      def resumed(basis, before, moves, record)
        raise stale_request unless record && (record.completed? || basis.printed_with?(record))

        started(basis.base_commit, before, AssessmentReport.recorded(record, basis, moves))
      end

      # Refuses, as stale, a correction read back from a completed record, as resumed allows, unless completing it
      # writes nothing: only an identical retry of the correction that completed it may read one, never an
      # earlier audit's record that git restore put back in place of the open one. An audit that read no record
      # back, one completed from its assessment, gives none.
      #: (AuditRecord?, Array[AuditRecord]) -> void
      def confirm_read_back(record, changes)
        raise stale_request if record&.completed? && !changes.empty?
      end

      # The map the audit began from: the current one when it is unchanged and the answer declares no change; or,
      # in git, the map at the base commit, which the block reads, refused unless the declared changes and any
      # members added explain every change. Outside git, a map that changed is refused.
      #: (CorrectionBasis, DeclaredMapChanges, map_file: String) { (String) -> Principle } -> Principle
      def map_started_from(basis, changes, map_file:, &)
        base = changes.base_to_read(basis.base_commit, @map, map_version: basis.map_version, map_file: map_file)
        return @map unless base

        started = yield(base)
        changes.check(started, @map, map_version: basis.map_version, map_file: map_file)
        started
      end

      # The hashes the audit began from (before), refused unless they were found and request_id is the one
      # printed for them and basis; a basis the answer edited is refused as that, not as a stale request.
      #: (RequestId, CorrectionBasis, Hash[String, String]?) -> Hash[String, String]
      def confirmed_start(request_id, basis, before)
        differs = basis.request_id(id, before || {}).differs_from(request_id)
        raise basis_edited(request_id) if differs == :handed
        raise stale_request unless before && differs.nil?

        before
      end

      # Each finding's outcome: its members and its disposition's action, where it is recorded, if anywhere, and
      # what a deferral says it waits on, if anything.
      # Then each prior finding kept; a new finding that raises one again keeps when it was first raised.
      #: (Array[untyped], Array[Disposition], ?DecidedPriorFindings) -> Array[untyped]
      def outcomes(findings, dispositions, prior = DecidedPriorFindings::NONE)
        findings.map do |finding|
          id = finding.fetch("id")
          disposition = dispositions.find { |each| each.finding_id == id } or raise KeyError, id
          finding.slice(*RecordedFinding::RAISED_FIELDS).merge(disposition.recorded_outcome, prior.first_raised(id))
        end + prior.kept
      end

      # What each member's assessment is judged on beside its text, from each member's loads: its map entry and when
      # it loads.
      #: (Hash[String, MemberLoads]) -> MemberGrounds
      def grounds(loads) = MemberGrounds.new(members, loads)

      # Which members' last assessments this audit carries forward, from the principle's record now, grounds, and the
      # question the request asks.
      #: (AuditRecord?, grounds: MemberGrounds, question: String) -> CarriedAssessments
      def carried_assessments(record, grounds:, question:)
        CarriedAssessments.new(record, members: members, judged_against: judged_against(question), now: @now,
                                       grounds: grounds)
      end

      # The members this audit lists to check against the map's activation, from each member's loads, each
      # with the decision the last completed audit, whose record is given, accepted on its loading.
      #: (Hash[String, MemberLoads], ?AuditRecord?) -> LoadsToCheck
      def loads_to_check(loads, record = nil)
        completed = record&.last_completed
        LoadsToCheck.new(activation: @map.activation, loads: loads, hashes: @now,
                         accepted: completed ? completed.members.loading_accepted(members) : {})
      end

      # The findings the last audit left for this one to decide, from its record.
      #: (AuditRecord?) -> PriorFindings
      def prior_findings(record)
        PriorFindings.new(record: record, now: @now, members: members)
      end

      # The project files the dispositions say changed: each fixed member's file, then each file where a
      # finding is recorded.
      #: (Array[Disposition]) -> Array[String]
      def changed_files(dispositions)
        fixed = dispositions.select(&:fixed?).flat_map(&:changed_members).map { |member| path_of(member) }
        (fixed + dispositions.filter_map(&:recorded_path)).uniq
      end

      # The path of the member with member_id in the map, refused as unknown_member when no member has it.
      #: (String) -> String
      def path_of(member_id) = members.found(member_id).path

      private

      # The members as the map lists them, which say each one's id and check.
      #: () -> PrincipleMembers
      def members = @map.members

      #: (RequestId) -> Error
      def basis_edited(request_id)
        Error.new("invalid_answer", "basis is not as request #{request_id} printed it",
                  "Give basis back as that request printed it; its keys may be in any order.",
                  fields: [{ "pointer" => "/basis", "problem" => "edited since it was printed" }])
      end

      # The ids of the members whose hash now differs from the one committed, the base commit's, gives; none
      # outside git.
      #: (Hash[String, String]?) -> Array[String]
      def changed_since(committed) = committed ? @now.reject { |member_id, sha| committed[member_id] == sha }.keys : []

      #: () -> Error
      def stale_request = StaleRequest.new(id).refusal
    end
  end
end

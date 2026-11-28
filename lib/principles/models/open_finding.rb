# typed: strict
# frozen_string_literal: true

require "time"
require_relative "audited_member_lines"
require_relative "evidence_item"
require_relative "evidence_replacements"
require_relative "recorded_finding"
require_relative "recorded_members"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One finding an audit record left open, deferred or accepted, with the principle and the time of that audit:
    # what list-open-findings prints of it, and what the next full audit is asked to decide on it.
    # PriorFindings is the next audit's view of all of them, and checks its decisions. It carries the evidence it
    # was raised with, which list-open-findings and the next full audit's request print, and which that audit keeps
    # when it keeps the finding.
    class OpenFinding
      # members are the members as the audit that left this finding open recorded them, against which the next
      # audit says whether each changed since.
      #: (RecordedFinding, principle_id: String, audited_at: String?, members: RecordedMembers) -> void
      def initialize(finding, principle_id:, audited_at:, members:)
        @finding = finding
        @principle_id = principle_id
        @audited_at = audited_at
        @members = members
        freeze
      end

      # The finding as list-open-findings prints it, with its principle, why it was left open, when its audit
      # was made and when it was first raised, so how long it has waited shows, what it says it waits on, since
      # when, and the evidence its record keeps, or that it keeps none.
      #: () -> Hash[String, untyped]
      def listed
        { "principle" => @principle_id, "finding_id" => id, "member_ids" => @finding.member_ids, **problem,
          "action" => @finding.action, **present("reason", @finding.reason), "recorded_at" => recorded_at&.to_h,
          "audited_at" => @audited_at, "first_raised_at" => first_raised_at, **raised_in, **waiting, **kept_evidence }
      end

      # The finding as the next full audit's request lists it, with why it was left open, which for an accepted one is
      # the owner's ruling, when it was first raised, what it waits on, since when, for the agent to confirm, and each
      # change made to it since its record.
      #: () -> Hash[String, untyped]
      def for_next_audit
        { "finding_id" => id, "member_ids" => @finding.member_ids, **problem,
          **present("recorded_at", recorded_at&.to_h),
          "action" => @finding.action, **present("reason", @finding.reason),
          "first_raised_at" => first_raised_at, **raised_in, **waiting,
          **present("changed_since_audit", @finding.changes_since_audit) }
      end

      # The finding as the next full audit's request lists it, against the map's members now and each one's hash
      # now, hashes_now: under its members' ids now, with whether each changed since the audit that left it open,
      # what its record did not keep of it, and the evidence it keeps, so the agent deciding it sees what it rests on.
      # Given since, each evidence item also carries what since says of it now.
      #: (PrincipleMembers, Hash[String, String]) ?{ (EvidenceItem) -> Hash[String, bool] }
      #|  -> Hash[String, untyped]
      def for_next_audit_against(members_now, hashes_now, &)
        finding = for_next_audit
        ids = ids_now(members_now)
        since = ids.to_h { |id| [id, since_this_audit(members_now, hashes_now, id)] }
        finding.merge("member_ids" => ids, "members_since" => since, **text_not_kept,
                      **kept_evidence(evidence_since(&)))
      end

      # The finding as the next full audit's record keeps it, before that audit's decision on it: under its members'
      # ids now, with why it was left open, its write-up, when it was first raised and the commit an earlier
      # first_raised_at cited.
      #: (PrincipleMembers) -> Hash[String, untyped]
      def kept_against(members_now)
        { "id" => id, "member_ids" => ids_now(members_now), **problem, "action" => @finding.action,
          **present("reason", @finding.reason), **present("recorded_at", recorded_at&.to_h),
          "first_raised_at" => first_raised_at, **raised_in }
      end

      # The principle whose record left it open.
      #: String
      attr_reader :principle_id

      # The finding's id in its record.
      #: () -> String
      def id = @finding.id

      # Where its write-up is, or nil when it was never written up.
      #: () -> WriteUpPointer?
      def recorded_at = @finding.recorded_at

      # What its audit did about it: deferred or accepted.
      #: () -> String?
      def action = @finding.action

      # Whether its record keeps what it says is wrong; one that keeps none is marked text_not_kept for the next full
      # audit to supply.
      #: () -> bool
      def states_problem? = !@finding.problem.nil?

      # The locators of the evidence it was raised with, or nil when its record keeps none.
      #: () -> Array[Hash[String, untyped]]?
      def evidence = @finding.evidence

      # The problem it states, and the one a still_holds decision gives in its place, as the completed result names
      # them, or nil when the decision gives none, its record states none or the two are the same.
      #: (String?) -> Hash[String, String]?
      def restated(problem)
        stated = @finding.problem
        { "finding_id" => id, "replaced" => stated, "with" => problem } if stated && problem && problem != stated
      end

      # Whether its record keeps the evidence it was raised with.
      #: () -> bool
      def evidence_kept? = @finding.evidence_kept?

      # The ids now, as the next full audit's request lists them, of its members no longer in the map, which its
      # members_since calls removed.
      #: (PrincipleMembers) -> Array[String]
      def removed_from(members_now) = ids_now(members_now).reject { |member_id| members_now.with_id(member_id) }

      # The new places a decision's problem_evidence gives the evidence its record keeps, so the check that an item is
      # no longer found and the swap read the same items; none when its record keeps none, which problem_evidence
      # gives instead.
      #: (Array[Hash[String, untyped]]?) -> EvidenceReplacements
      def replacements(problem_evidence)
        kept = evidence or return EvidenceReplacements.new([], [])

        EvidenceReplacements.new(kept, problem_evidence || [])
      end

      # The evidence its next record keeps after a decision gives problem_evidence: the evidence it was raised with,
      # each item the decision gave a new place swapped for it, or, when its record keeps none, the evidence the
      # decision gave, kept as plain evidence since the record does not care which audit gave it.
      #: (Array[Hash[String, untyped]]?) -> Array[Hash[String, untyped]]?
      def evidence_after(problem_evidence) = evidence ? replacements(problem_evidence).evidence : problem_evidence

      # Whether it names the member known by key, under whichever id its audit recorded that member, so a member
      # renamed since is still found.
      #: (String) -> bool
      def on?(key) = @finding.member_ids.any? { |member_id| @members.key_of(member_id) == key }

      # The finding as another principle's full audit lists it, once, under open_findings_elsewhere, so the same
      # problem is not raised again there, with each item of its evidence and what its lines are beside
      # lines, that audit's members, where locate finds the item now, or that its record keeps none.
      #: (AuditedMemberLines) { (Locator) -> LocatedText } -> Hash[String, untyped]
      def listed_elsewhere(lines, &)
        located = items&.map { |item| lines.facts_of(item, &) }
        { "principle_id" => @principle_id, "finding_id" => id, **problem, **present("action", @finding.action),
          **kept_evidence(located) }
      end

      # When the finding was first raised, which orders the findings by how long each has waited.
      #: () -> Time
      def first_raised_time = Time.iso8601(first_raised_at.to_s)

      # The finding as the session-start line names it: its principle, id and action, the whole days it has waited
      # since it was first raised until now, and what it says it waits on, when it says.
      #: (Time) -> Hash[String, untyped]
      def waited_at(now)
        { "principle" => @principle_id, "finding_id" => id, "action" => @finding.action,
          "days_open" => ((now - first_raised_time) / 86_400).floor, **present("waits_on", @finding.waits_on) }
      end

      # Whether it records no waits_on, so the session-start line can count those whose line it cannot show.
      #: () -> bool
      def without_waits_on? = !@finding.waits_on

      # Whether it is deferred with no waits_on, so the session-start line counts it among those to raise; an
      # accepted one waits on no one by design.
      #: () -> bool
      def waiting_on_no_one_named? = action == "deferred" && without_waits_on?

      # Whether it is deferred with a waits_on, so the session-start line counts it among those waiting on someone
      # named, for the agent to judge whom.
      #: () -> bool
      def waiting_on_someone_named? = action == "deferred" && !without_waits_on?

      # The one line it says it waits on, or nil when it says it waits on nothing.
      #: () -> String?
      def waits_on = @finding.waits_on

      # What the finding says it waits on, and since when: its own waits_on_since when an earlier audit asked it, or
      # else this audit's time; nothing when it says it waits on nothing.
      #: () -> Hash[String, untyped]
      def waiting
        line = @finding.waits_on or return {}
        { "waits_on" => line, "waits_on_since" => @finding.waits_on_since || @audited_at }
      end

      # Its own first_raised_at when an earlier audit kept it, or else this audit's time.
      #: () -> String?
      def first_raised_at = @finding.first_raised_at || @audited_at

      private

      # Its members' ids now, each member found by key so a member renamed since keeps its new id.
      #: (PrincipleMembers) -> Array[String]
      def ids_now(members_now) = @finding.member_ids.map { |id| id_now(members_now, @members.key_of(id)) || id }

      #: (PrincipleMembers, String) -> String?
      def id_now(members_now, key) = members_now.with_key(key)&.id

      #: (PrincipleMembers, Hash[String, String], String) -> String
      def since_this_audit(members_now, hashes_now, id)
        member = members_now.with_id(id) or return "removed"
        @members.freshness(member.key, hashes_now.fetch(id))
      end

      # The commit whose record an audit cited for an earlier first_raised_at, when one did.
      #: () -> Hash[String, untyped]
      def raised_in = present("raised_in", @finding.raised_in)

      # Its evidence items, each with what since says of it now, or as kept without it.
      #: () ?{ (EvidenceItem) -> Hash[String, bool] } -> Array[Hash[String, untyped]]?
      def evidence_since(&since)
        return @finding.evidence unless since

        items&.map { |item| item.with_facts(since.call(item)) }
      end

      # The evidence it was raised with, as items, or nil when its record keeps none.
      #: () -> Array[EvidenceItem]?
      def items = @finding.evidence&.map { |fields| EvidenceItem.new(fields) }

      # A mark when its record keeps no problem statement, for the next full audit to supply.
      #: () -> Hash[String, untyped]
      def text_not_kept = states_problem? ? {} : { "text_not_kept" => true }

      # The evidence its record keeps, as items, which another principle's audit gives with each item's lines, or the
      # mark that it keeps none, as a record written before this tool kept evidence does.
      #: (?Array[Hash[String, untyped]]?) -> Hash[String, untyped]
      def kept_evidence(listed = @finding.evidence)
        evidence_kept? ? { "evidence" => listed } : { "evidence_not_kept" => true }
      end

      # What it says is wrong, under its key, or nothing when the record kept no text for it.
      #: () -> Hash[String, untyped]
      def problem = present("problem", @finding.problem)

      # value under name, or nothing when there is none, as the record leaves out a field it has no value for.
      #: (String, untyped) -> Hash[String, untyped]
      def present(name, value) = value.nil? ? {} : { name => value }
    end
  end
end

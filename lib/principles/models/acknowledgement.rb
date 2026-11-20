# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "acknowledged_check"
require_relative "acknowledgement_left_as_printed"
require_relative "acknowledgement_refusal"
require_relative "acknowledgements"
require_relative "request_id"
require_relative "audit_record"
require_relative "member"
require_relative "member_lines"
require_relative "placement"
require_relative "quoted_change"
require_relative "reported_check"
require_relative "template_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A one-member audit: the agent says a committed change to one member keeps its meaning, quoting a line
    # from before and after it, so the record's baseline for that member moves on and --short stops repeating it.
    # Refused outside git, for a member no completed audit assessed, and for an unchanged or checked member.
    class Acknowledgement
      PHASE = "acknowledgement"
      # The text the answer's template prints in each field the agent judges, which an answer may not send back, so
      # a template returned as printed acknowledges nothing. It prints no quotes, which an answer leaving them
      # out reads as first_changed_lines. After a pure insertion, meaning_kept's says that an
      # inserted line usually adds a rule, for an agent that reads the template alone.
      PLACEHOLDERS = TemplatePlaceholders.new(
        { "meaning_kept" => "true only if the member still says the same thing",
          "reason" => "Why, in one line of your own" },
        also_printed: { "meaning_kept" => "true only if the member still says the same thing; this change inserted " \
                                          "a line, which usually adds a rule" }
      ) #: TemplatePlaceholders
      # The text a checked member's template prints where its check's exit status goes, short since the request's
      # context says how to run the check.
      EXIT_STATUS_PLACEHOLDER = ReportedCheck::EXIT_STATUS_PLACEHOLDER #: String
      # The fields an answer may not send back as the template printed them, refused before its shape.
      LEFT_AS_PRINTED = AcknowledgementLeftAsPrinted.new(
        PLACEHOLDERS, exit_status: EXIT_STATUS_PLACEHOLDER
      ) #: AcknowledgementLeftAsPrinted

      # The placeholders the template prints beside quotes, its first_changed_lines.
      #: (Hash[String, String]) -> Hash[String, untyped]
      def self.placeholders_beside(quotes)
        quotes["old_line"] == "" ? PLACEHOLDERS.with_other_text_in("meaning_kept") : PLACEHOLDERS.to_h
      end

      # before holds the member's lines at its baseline commit, now its lines and hash at base, HEAD.
      #: (principle_id: String, member: Member, record: AuditRecord?, base: String?, now_sha256: String) -> void
      def initialize(principle_id:, member:, record:, base:, now_sha256:)
        @principle_id = principle_id
        @member = member
        @record = record
        @base = base
        @now_sha256 = now_sha256
        freeze
      end

      # The member's lines at its baseline and now, which the answer quotes; refused when the member cannot be found
      # where its baseline was read, since there is no line there to quote; #baseline reads a moved member
      # where the map then placed it.
      #: (MemberLines?) -> MemberLines
      def compared(lines)
        lines or refuse("it cannot be found in its file at its baseline commit #{last_judged_commit}")
      end

      # The member's baseline: the oldest of placements, from the commit it was last judged at on, that holds the
      # text the record vouches for, which is later than that commit when its full audit fixed it, and as the
      # map then placed it when it has moved since. Refused when none does, since that text is not the
      # audited one.
      #: (Enumerable[Placement]) -> Placement
      def baseline(placements)
        recorded = acknowledgeable.members.hash_for(@member.key)
        placements.find { |placement| placement.holds?(recorded) } ||
          refuse("its text does not match the audit record at #{last_judged_commit} or any later commit")
      end

      # Where the member was at baseline, when that is not where it is now, as after a move.
      #: (Placement) -> Hash[String, untyped]?
      def moved_from(baseline)
        baseline.reference unless baseline.reference == @member.reference
      end

      # The paths the change since baseline spans, which the baseline's placement owns.
      #: (Placement) -> Array[String]
      def paths_since(baseline) = baseline.paths_to(@member.path)

      # The commit the member was last judged at, when baseline is later than it, as when the member's own full
      # audit fixed it after its base.
      #: (Placement) -> String?
      def audit_base(baseline)
        judged = last_judged_commit
        judged unless baseline.commit == judged
      end

      # The commit the member was last judged at: its last acknowledgement's, or the audit's base commit. Refused
      # unless the member can be acknowledged now.
      #: () -> String
      def last_judged_commit
        record = acknowledgeable
        record.members.acknowledgements_for(@member.key).last&.fetch("commit") || record.base_commit.to_s
      end

      # Keep the record's named reference and stable member key together during placement lookup.
      #: (Project) -> Enumerator::Lazy[Placement]
      def placements_in(project)
        commit = last_judged_commit
        fields = project.principles.find(@principle_id).member(@member.id)
        project.principle_history(@principle_id).placements_since(commit, @member.key, fields)
      end

      # The request's id: the member, its hash at the baseline and now, and the commit it is judged at.
      #: () -> RequestId
      def request_id
        RequestId.for(principle_id: @principle_id, phase: PHASE,
                      parts: [@member.key, acknowledgeable.members.hash_for(@member.key), @now_sha256, @base])
      end

      # The ids of the deferred and the accepted findings the last audit left on this member, which the request
      # and the acknowledgement name, the accepted ones since an edit may bear on whether they still hold
      #: () -> Hash[String, Array[String]]
      def open_findings
        { "deferred_findings" => findings_on_member("deferred"), "accepted_findings" => findings_on_member("accepted") }
      end

      # Whether the last audit deferred a finding on this member, which acknowledging it leaves open for a full audit.
      #: () -> bool
      def keeps_deferred_findings? = findings_on_member("deferred").any?

      # The answer's entry for its member, under members by the member's id as several members' entries are;
      # refused when members leaves it out or holds another member.
      #: (untyped) -> untyped
      def entry_in(answer)
        entries = answer.fetch("members")
        refusal = Acknowledgements.unmatched(missing: [@member.id] - entries.keys, extra: entries.keys - [@member.id],
                                             named_by: "basis.member_ids")
        raise refusal if refusal

        entries.fetch(@member.id)
      end

      # The record with this member's baseline moved to its text now, once the answer is checked against the
      # member's lines at the baseline commit and now. The change keeps the check run the answer reported, which the
      # member's check_result cannot show was this run when the last audit's passed with the same command.
      # into is the record the change is made to: the one this member is judged against, unless another member's
      # acknowledgement in the same answer has already changed it. listed is what the member's check lists now, when
      # it is this tool's own list-member-problems.
      #: (untyped, MemberLines, at: String, ?into: AuditRecord?, ?listed: ListedMembers?) -> AuditRecord
      def accepted(answer, lines, at:, into: nil, listed: nil)
        checked(answer, lines)
        result = check_result(answer, listed)
        run = result ? { "check_result" => result.slice("command", "exit_status") } : {}
        from = acknowledgeable.members.hash_for(@member.key)
        (into || acknowledgeable).acknowledged(@member.key, { "from_sha256" => from, "to_sha256" => @now_sha256,
                                                              "commit" => @base, "reason" => answer.fetch("reason"),
                                                              "acknowledged_at" => at, **open_findings, **run },
                                               check_result: result)
      end

      # The result the answer reports for the member's check, once it passed; nil for a member without a check.
      #: (untyped, ?ListedMembers?) -> Hash[String, untyped]?
      def check_result(answer, listed = nil)
        AcknowledgedCheck.new(member: @member, principle_id: @principle_id, record: acknowledgeable, listed:)
                         .result(answer)
      end

      # The first line on each side of the change that the other lacks, which the request hints the quotes from.
      #: (MemberLines) -> Hash[String, String]
      def first_changed_lines(lines) = quoted_change(lines).first_changed_lines

      private

      # The change the answer quotes, between the member's lines at the baseline and now.
      #: (MemberLines) -> QuotedChange
      def quoted_change(lines) = QuotedChange.new(lines, member_id: @member.id)

      # The ids of the findings the last audit left open on this member with action, found by key, so a member moved
      # since keeps its findings.
      #: (String) -> Array[String]
      def findings_on_member(action)
        acknowledgeable.left_open.select { |finding| finding.action == action && finding.on?(@member.key) }.map(&:id)
      end

      # The completed record, once the member can be acknowledged.
      #: () -> AuditRecord
      def acknowledgeable
        refuse("an acknowledgement is judged against committed text, so it needs git") unless @base
        record = @record or no_completed_audit
        AcknowledgementRefusal.of(record, @member, now_sha256: @now_sha256)&.raise!
        record
      end

      #: (untyped, MemberLines) -> void
      def checked(answer, lines)
        refuse("the answer says the change does not keep #{@member.id}'s meaning") unless answer["meaning_kept"] == true
        reason = answer.fetch("reason").to_s
        refuse("the reason must be one line") if reason.include?("\n")
        change = quoted_change(lines)
        quotes = change.first_changed_lines.merge(answer.slice("old_line", "new_line"))
        change.check(old_line: quotes.fetch("old_line"), new_line: quotes.fetch("new_line"))
      end

      #: (String) -> bot
      def refuse(why) = AcknowledgementRefusal.new(@member, @principle_id).refuse(why)

      #: () -> bot
      def no_completed_audit = AcknowledgementRefusal.new(@member, @principle_id, :not_completed).raise!
    end
  end
end

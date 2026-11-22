# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/acknowledgement"
require_relative "../models/acknowledgement_placeholders"
require_relative "../models/check_since_last_audit"
require_relative "../models/list_member_problems_check"
require_relative "../models/listed_members"
require_relative "../models/member"
require_relative "../views/member_change_since_baseline"
require_relative "../views/printed_json"
require_relative "../views/one_member_check_result_template"
require_relative "../views/read_the_change"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # One member's acknowledgement as a one-member audit asks and answers it, which Acknowledgement hands over:
    # the member's change since its baseline as the request shows it, the context beside it and the placeholders its
    # template prints, and the record with the acknowledgement in it once the answer holds.
    class MemberAcknowledgement < Command
      # The text the template prints in each field the agent writes: its judgement's placeholders, meaning_kept's
      # chosen by whether the change's first_changed_lines is a pure insertion, and check_result's for a
      # checked member. The quotes the answer reads as first_changed_lines when left out are not printed.
      #: (Hash[String, untyped]?, ?Views::MemberChangeSinceBaseline?) -> Hash[String, untyped]
      def self.placeholders(check_result, change = nil)
        quotes = change&.first_changed_lines.to_h
        { **Models::AcknowledgementPlaceholders.beside(quotes),
          **(check_result ? { "check_result" => check_result } : {}) }
      end

      #: Models::Acknowledgement
      attr_reader :acknowledgement
      #: Models::Member
      attr_reader :member

      # principle_id's member member_id, refused as a near miss or an unknown id, judged against the principle's
      # record from the commit its map and file were last committed at.
      #: (Models::Project, tool: RunningTool, principle_id: String, member_id: String) -> void
      def initialize(project, tool:, principle_id:, member_id:)
        super(project, tool: tool)
        @id = principle_id
        @member = Models::Member.new(@principles.find(principle_id).member(member_id)) #: Models::Member
        @base = @history.base_commit(principle_id, [@principles.file(principle_id), @member.path]) #: String?
        @acknowledgement = Models::Acknowledgement.new(
          principle_id:, member: @member, record: @audit_records.find(principle_id), base: @base,
          now_sha256: @project.located_text(@member.locator).sha256
        ) #: Models::Acknowledgement
      end

      # The member's part of its request: its change since its baseline, as the request shows it, the context
      # beside it, its findings left open and how to run and report its check, and the placeholders its template
      # prints.
      #: () -> Hash[Symbol, untyped]
      def asked
        baseline, lines = since_baseline
        check = check_template
        change = Views::MemberChangeSinceBaseline.new(
          member: shown(baseline), member_lines: lines.shown(taken: bytes_of(check)),
          first_changed_lines: @acknowledgement.first_changed_lines(lines), commits: commits(baseline),
          read_the_change: read_the_change(baseline)
        )
        { change:, context: { **@acknowledgement.open_findings, **instruction_for(check) },
          placeholders: MemberAcknowledgement.placeholders(check&.to_h, change) }
      end

      # The record with the acknowledgement in it, once its quotes are found at the baseline and now, made to into
      # when another member's acknowledgement in the same answer has already changed the record.
      # acknowledging is every member the answer acknowledges, which its check may list, each as its principle id and
      # member id: this member alone unless the answer is to several, of one principle or several.
      #: (untyped, at: String, ?acknowledging: Array[[String, String]], ?into: Models::AuditRecord?)
      #|  -> Models::AuditRecord
      def accepted(response, at:, acknowledging: [[@id, @member.id]], into: nil)
        _baseline, lines = since_baseline
        @acknowledgement.accepted(response, lines, at:, into:, listed: listed(acknowledging))
      end

      private

      # What the member's check lists now beside the members the answer acknowledges, when the check is this
      # tool's own list-member-problems --short; nil for any other check.
      #: (Array[[String, String]]) -> Models::ListedMembers?
      def listed(acknowledging)
        own_listing&.listed(@project, principle_id: @id, acknowledging:)
      end

      # The request's check_instruction for a checked member, how to run and report its check; none without one.
      #: (Views::OneMemberCheckResultTemplate?) -> Hash[String, String]
      def instruction_for(check) = check ? { "check_instruction" => check.instruction } : {}

      # The bytes the check's template and instruction take as the request prints them, which the member's lines
      # give up.
      #: (Views::OneMemberCheckResultTemplate?) -> Integer
      def bytes_of(check) = check ? Views::PrintedJson.bytes(check.to_h) + check.instruction.bytesize : 0

      # The check_result a checked member's answer fills, for the check the last audit ran, which a one-member audit
      # requires, asking for a passing run alone; nil for a member without a check.
      #: () -> Views::OneMemberCheckResultTemplate?
      def check_template
        checks = Models::CheckSinceLastAudit.new(principle_history: principle_history(@id),
                                                 record: @audit_records.find(@id))
        exit_status = Models::AcknowledgementPlaceholders::EXIT_STATUS_PLACEHOLDER
        Views::OneMemberCheckResultTemplate.for(checks.entry(@member), exit_status:, own_listing: !own_listing.nil?)
      end

      # The member's check read as this tool's own list-member-problems --short; nil for any other.
      #: () -> Models::ListMemberProblemsCheck?
      def own_listing = Models::ListMemberProblemsCheck.of(@member.check.to_s)

      # The command that shows the member's change from its baseline to the base commit: the history of its own lines
      # where it is now, which the base commit holds, when Member#traced_lines says so, else its file's diff.
      #: (Models::Placement) -> Views::ReadTheChange
      def read_the_change(baseline)
        paths = @acknowledgement.paths_since(baseline)
        lines = @member.traced_lines(paths, @project.located_text(@member.locator).lines)
        Views::ReadTheChange.new(since: baseline.commit, to: @base.to_s, paths:, lines:)
      end

      # The member as the request shows it, with where it was at its baseline when it has moved since.
      #: (Models::Placement) -> Hash[String, untyped]
      def shown(baseline)
        moved_from = @acknowledgement.moved_from(baseline)
        { "id" => @member.id, "role" => @member.role, **(@member.check ? { "check" => @member.check } : {}),
          "evidence" => [@member.reference],
          **(moved_from ? { "evidence_at_baseline" => [moved_from] } : {}) }
      end

      # The commits the request names: the baseline's, HEAD, and the audit's base when the baseline is later.
      #: (Models::Placement) -> Hash[String, String]
      def commits(baseline)
        audit_base = @acknowledgement.audit_base(baseline)
        { "baseline" => baseline.commit, "base" => @base.to_s, **(audit_base ? { "audit_base" => audit_base } : {}) }
      end

      # The member's baseline, the oldest commit from the one it was last judged at that holds the text the audit
      # record vouches for, placed as that commit's map placed it or as it is placed now, and its own
      # lines there and now, which the answer's quotes are checked against.
      #: () -> [Models::Placement, Models::MemberLines]
      def since_baseline
        baseline = @acknowledgement.baseline(@acknowledgement.placements_in(@project))
        lines = @project.member_lines(@member.locator, since: baseline.commit, then_locator: baseline.locator)
        [baseline, @acknowledgement.compared(lines)]
      end
    end
  end
end

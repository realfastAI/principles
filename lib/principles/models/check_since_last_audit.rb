# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "audit_record"
require_relative "member"
require_relative "principle_history"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Whether a member's check is the one the principle's last audit was given an exit status for, and, when
    # it is not, the commit that made it what it is now. A check is a command any collaborator can change in the
    # committed map, and the audit asks the agent to run it, so a check no audit has seen needs a review
    # first. This tool states the fact; the review is the agent's step.
    class CheckSinceLastAudit
      #: (principle_history: PrincipleHistory, record: AuditRecord?) -> void
      def initialize(principle_history:, record:)
        @principle_history = principle_history
        @record = record
        freeze
      end

      # "unchanged" when the last audit was given an exit status for this same check; otherwise "new" or
      # "changed", with changed_in the oldest commit of the unbroken run, back from HEAD, whose map holds it,
      # and, when changed, last_run, the command the last audit ran. Beside an unchanged check, the line saying what its
      # last review rested on and since when; beside a changed one, last_run_review_basis, that line for the command
      # the last audit ran, not this one.
      # changed_in is nil outside git, or when no commit holds it. The walk stops at a map it cannot read, so
      # changed_in may then name a later commit than the one that set the check: the review is still asked for.
      #: (Member, String) -> Hash[String, untyped]
      def of(member, check)
        status = status_of(member.key, check)
        review = review_of(member.key)
        return { "status" => "unchanged", **review } if status == :unchanged

        changed_in = commit_that_set(member.key, check)
        return { "status" => "new", "changed_in" => changed_in } if %i[new not_run].include?(status)

        ran = @record&.check_run_for(member.key)
        last_run_review = review.slice("review_basis").transform_keys { "last_run_review_basis" }
        { "status" => "changed", "last_run" => ran, **last_run_review, "changed_in" => changed_in }
      end

      # The member's check and how it stands to the last audit's, as a request lists them beside the member; nothing
      # for a member without a check.
      #: (Member) -> Hash[String, untyped]
      def entry(member)
        check = member.check or return {}
        { "check" => check, "check_since_last_audit" => of(member, check) }
      end

      private

      # How check stands to the one the last audit ran, as its record says; new when there is no record.
      #: (String, String) -> Symbol
      def status_of(key, check) = @record ? @record.members.check_since(key, check) : :new

      # The line the last audit's record keeps for what the review of its run rested on, and since when, as a run
      # keeping it carries it: undated while the audit that first kept it is still open.
      #: (String) -> Hash[String, untyped]
      def review_of(key) = @record&.check_review_carried_for(key) || {}

      #: (String, String) -> String?
      def commit_that_set(key, check)
        run = @principle_history.runs([key]).fetch(key)
        run.take_while { |_sha, fields| Member.new(fields).check == check }.last&.first
      end
    end
  end
end

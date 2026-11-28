# typed: strict
# frozen_string_literal: true

require_relative "prompts"
require_relative "request_part"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How the next full audit shows the findings the last one deferred or accepted, for it to decide.
    class PriorFindingsResult
      # The part this lists, by the name the request prints it under and start-audit --part takes.
      PART = "prior_findings" #: String

      # prior is each finding the last audit deferred or accepted, as the request lists it; last_audited_commit is the
      # commit each evidence item's changed_since_last_audit compares against, or nil when none says.
      # placeholders is the text the answer printed alone gives the decision, naming what it may be, and each
      # field a decision may give, which an answer leaves as printed to give none.
      #: (Array[Hash[String, untyped]], placeholders: Hash[String, untyped], ?last_audited_commit: String?) -> void
      def initialize(prior, placeholders:, last_audited_commit: nil)
        @prior = prior
        @placeholders = placeholders
        @last_audited_commit = last_audited_commit
        freeze
      end

      # The assessment request's part that lists the prior findings, with how to decide them and a decision to fill
      # in for each; nil when there are none.
      #: () -> RequestPart?
      def part
        return if @prior.empty?

        RequestPart.new(shown: { PART => @prior.map { |finding| shown(finding) } },
                        instructions: [Instruction.new("prior_findings_instruction", instruction)],
                        slots: { "prior_finding_decisions" => @prior.map { |finding| decision(finding) } },
                        help: { "prior_finding_decisions" => @placeholders },
                        alone: { "prior_finding_decisions" => @prior.map { |finding| decision_alone(finding) } })
      end

      private

      # finding as the request lists it, asking beside it, when it is marked evidence_not_kept, for the evidence its
      # record lacks, where the agent deciding it reads.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def shown(finding)
        return finding unless evidence_not_kept?(finding)

        finding.merge("evidence_request" => Prompts.text("assess-every-member/give-problem-evidence-at-still-holds"))
      end

      # The decision to fill in on finding, with an empty problem_evidence list when it is marked evidence_not_kept,
      # so an agent filling the template alone sees the field its record lacks.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def decision(finding)
        decision = { "finding_id" => finding.fetch("finding_id"), "decision" => nil }
        evidence_not_kept?(finding) ? decision.merge("problem_evidence" => []) : decision
      end

      # The decision to fill in on finding in the answer printed alone, which no list of prior findings stands beside,
      # with the finding's problem after its id, so the agent deciding it can tell what it is.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def decision_alone(finding)
        { "finding_id" => nil, "finding_problem" => finding.fetch("problem"), **decision(finding) }
      end

      # How to decide the prior findings, naming each one's id, so a new finding is given another, each paragraph with
      # whether its case holds: how to keep what a deferral waits on holds only when one carries waits_on, how to
      # claim an earlier first_raised_at never, since no fact marks a finding dated late, so it is read whole, and how
      # to give the evidence a finding's record lacks only when one is marked so.
      #: () -> Array[[String, bool]]
      def instruction
        ids = @prior.map { |finding| finding.fetch("finding_id") }.join(", ")
        decide = Prompts.text("assess-every-member/decide-each-prior-finding", ids: ids).split("\n\n")
        [*decide.map { [it, true] },
         [Prompts.text("assess-every-member/keep-or-change-what-a-deferral-waits-on"), waits_on?],
         [Prompts.text("assess-every-member/claim-an-earlier-first-raised-at"), false], *evidence_since,
         [Prompts.text("assess-every-member/give-the-evidence-a-prior-finding-lacks"), marked_evidence_not_kept?]]
      end

      # How to read each evidence item's changed_since_last_audit, naming the commit it compares against, holding only
      # when an item carries it; none when no commit is named to compare against.
      #: () -> Array[[String, bool]]
      def evidence_since
        return [] unless @last_audited_commit

        said = @prior.any? { |finding| finding["evidence"]&.any? { it.key?("changed_since_last_audit") } }
        [[Prompts.text("assess-every-member/read-whether-each-prior-finding-s-evidence-changed",
                       commit: @last_audited_commit), said]]
      end

      # Whether any prior finding carries a waits_on line.
      #: () -> bool
      def waits_on? = @prior.any? { |finding| finding["waits_on"] }

      #: () -> bool
      def marked_evidence_not_kept? = @prior.any? { |finding| evidence_not_kept?(finding) }

      # Whether finding is marked as one whose record keeps no evidence.
      #: (Hash[String, untyped]) -> bool
      def evidence_not_kept?(finding) = finding["evidence_not_kept"] == true
    end
  end
end

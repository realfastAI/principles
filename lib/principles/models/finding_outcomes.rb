# typed: strict
# frozen_string_literal: true

require_relative "decided_prior_findings"
require_relative "recorded_finding"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The findings a completed full audit records: each finding its assessment raised, with its correction's
    # disposition, each prior finding the audit kept, and each finding a fix raised from the part of its finding it
    # left unfixed.
    class FindingOutcomes
      # findings are those the assessment raised, dispositions the correction's, one for each, and prior the
      # decisions on the findings the last audit left open.
      #: (Array[untyped], Array[Disposition], DecidedPriorFindings) -> void
      def initialize(findings, dispositions, prior)
        @findings = findings
        @dispositions = dispositions
        @prior = prior
        freeze
      end

      # Each finding's outcome: its members and its disposition's action, where it is recorded, if anywhere, and
      # what a deferral says it waits on, if anything.
      # Then each prior finding kept; a new finding that raises one again keeps when it was first raised. Then each
      # finding raised from an unfixed part, which keeps when the finding it was part of was first raised.
      #: () -> Array[untyped]
      def recorded
        raised = @findings.map do |finding|
          id = finding.fetch("id")
          outcome = disposition_of(id).recorded_outcome
          finding.slice(*RecordedFinding::RAISED_FIELDS).merge(outcome, @prior.first_raised(id))
        end + @prior.kept
        @findings.reduce(raised) { |so_far, finding| with_unfixed_part(so_far, finding) }
      end

      private

      #: (untyped) -> Disposition
      def disposition_of(id) = @dispositions.find { |each| each.finding_id == id } || raise(KeyError, id)

      # recorded, with the finding raised from the part of finding its fix left unfixed, if any, refused when an id
      # in recorded is its id.
      #: (Array[untyped], Hash[String, untyped]) -> Array[untyped]
      def with_unfixed_part(recorded, finding)
        id = finding.fetch("id")
        part = disposition_of(id).unfixed_part
        return recorded unless part

        recorded + [part.raised_from(finding, recorded.map { it.fetch("id") }).merge(@prior.first_raised(id))]
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "audit_record"
require_relative "last_completed_revision"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What an assessment request prints as its basis, which the agent hands back with the answer: the commit the
    # audit is based on, nil outside git, and the revision of the last completed audit record when the request was
    # printed, nil when there was none, so the answer is refused once that record changed.
    class AssessmentBasis
      # The basis printed for an audit based on base, after record, the principle's audit record now, if any.
      #: (String?, AuditRecord?) -> AssessmentBasis
      def self.printed(base, record)
        new("base_commit" => base, "last_completed_revision" => record&.last_completed&.revision)
      end

      # audited_change is the commit that last changed the map's file or a member's file at the base, which the id
      # digests in place of the base, so a commit elsewhere leaves the id as it was; the base until given.
      #: (Hash[String, untyped], ?String?) -> void
      def initialize(fields, audited_change = fields["base_commit"])
        @fields = fields
        @audited_change = audited_change
        freeze
      end

      # This basis, its id digesting commit, the last change to the files the audit reads at its base, nil outside git.
      #: (String?) -> AssessmentBasis
      def audited_at(commit) = AssessmentBasis.new(@fields, commit)

      #: () -> Hash[String, untyped]
      def to_h = @fields

      # The commit the audit is based on, nil outside git.
      #: () -> String?
      def base = @fields["base_commit"]

      # The last completed record's revision when the request was printed, nil when there was none, which the
      # correction the assessment prints carries forward.
      #: () -> String?
      def revision = @fields["last_completed_revision"]

      # The last completed record's revision when the request was printed, which refuses the answer once it changed.
      #: () -> LastCompletedRevision
      def printed_after = LastCompletedRevision.new(revision)

      # What the request id digests of the basis, in a fixed order, so how the answer orders its keys changes nothing.
      #: () -> Array[String?]
      def digested = [@audited_change, revision]
    end
  end
end

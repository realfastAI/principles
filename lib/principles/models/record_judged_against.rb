# typed: strict
# frozen_string_literal: true

require_relative "audit_record"
require_relative "carried_assessments"
require_relative "loads_to_check"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The principle's audit record as it stands when an assessment answer is judged against it, each part read from
    # that one record: the members whose loads the answer must decide, the assessments it may carry
    # forward, and the command it ran for each member's check.
    class RecordJudgedAgainst
      # record is the principle's stored record, open or completed, nil when it has none.
      #: (loads: LoadsToCheck, carried: CarriedAssessments, record: AuditRecord?) -> void
      def initialize(loads:, carried:, record:)
        @loads = loads
        @carried = carried
        @record = record
        freeze
      end

      # The members whose loading the answer decides, and the decisions the record accepted.
      #: LoadsToCheck
      attr_reader :loads

      # Which members' last assessments the answer may carry forward.
      #: CarriedAssessments
      attr_reader :carried

      # The command the stored record was given an exit status for, for the member known by key, as
      # check_since_last_audit reads it: nil when it ran none for that member.
      #: (String) -> String?
      def check_run_for(key) = @record&.check_run_for(key)

      # The line saying what the review of that run rested on, and since when, as an answer keeping it carries it.
      #: (String) -> Hash[String, untyped]
      def check_review_for(key) = @record&.check_review_carried_for(key) || {}
    end
  end
end

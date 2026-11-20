# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "audit_record"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The correction a full audit's assessment with findings opened, as principle id's audit record keeps it while
    # the audit is open, which show-open-correction prints again: its request id, its basis and the findings that
    # basis asks the correction to dispose of.
    class OpenCorrection
      # The repair while the open record keeps no correction, as one an earlier release wrote.
      SUBMIT_AGAIN = "Submit this audit's assessment again, which prints its correction and keeps it to print " \
                     "again." #: String

      #: String
      attr_reader :request_id
      # The basis as printed, which the answer hands back unchanged.
      #: Hash[String, untyped]
      attr_reader :basis

      # The correction record keeps, the record of principle id in file; refused when there is none: no record, a
      # completed one, or an open one an earlier release wrote, which keeps none.
      #: (String, AuditRecord?, file: String) -> OpenCorrection
      def self.kept(id, record, file:)
        kept = record&.correction
        return new(kept.fetch("request_id"), kept.fetch("basis")) if kept

        raise Error.new("no_open_correction", "#{id} has no open correction to print", repair(id, open: record&.open?),
                        file)
      end

      # How to get a correction to print: submit the open audit's assessment again, which prints it and keeps it in
      # the record, or start a full audit when none is open.
      #: (String, open: bool?) -> String
      def self.repair(id, open:)
        return SUBMIT_AGAIN if open

        "Start a full audit, whose assessment with findings opens a correction: #{Error::EXECUTABLE} start-audit #{id}"
      end
      private_class_method :repair

      #: (String, Hash[String, untyped]) -> void
      def initialize(request_id, basis)
        @request_id = request_id
        @basis = basis
        freeze
      end

      # The findings the basis asks the correction to dispose of.
      #: () -> Array[Hash[String, untyped]]
      def findings = @basis.fetch("findings")
    end
  end
end

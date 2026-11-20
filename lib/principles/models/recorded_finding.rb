# typed: strict
# frozen_string_literal: true

require_relative "write_up_pointer"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One finding as an audit record holds it: its id, what the audit did about it and where it is written up.
    # AuditRecord reads its findings only through this value.
    class RecordedFinding
      # What a finding an assessment raised carries to its record, through the correction's basis: the one list of
      # those fields, so the basis and the record cannot carry different ones.
      RAISED_FIELDS = %w[id member_ids problem evidence].freeze #: Array[String]

      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields.freeze #: Hash[String, untyped]
        freeze
      end

      #: () -> String
      def id = @fields.fetch("id")

      # The ids of the members it is on, as its audit recorded them.
      #: () -> Array[String]
      def member_ids = @fields.fetch("member_ids")

      # What it says is wrong, or nil when the record kept no text for it.
      #: () -> String?
      def problem = @fields["problem"]

      # What its audit did about it: fixed, deferred or accepted.
      #: () -> String?
      def action = @fields["action"]

      # Why its audit left it unfixed, or nil when it was fixed or its record predates keeping the reason.
      #: () -> String?
      def reason = @fields["reason"]

      # Where its write-up is, or nil when it was never written up.
      #: () -> WriteUpPointer?
      def recorded_at
        fields = @fields["recorded_at"]
        WriteUpPointer.new(fields) if fields
      end

      # When it was first raised, when an earlier audit raised it; nil when its own audit did.
      #: () -> String?
      def first_raised_at = @fields["first_raised_at"]

      # The locators of the evidence it was raised with, or nil when its record keeps none.
      #: () -> Array[Hash[String, untyped]]?
      def evidence = @fields["evidence"]

      # Whether its record keeps the evidence it was raised with; one written before this tool kept evidence, or kept
      # by a still_holds decision that gave none, keeps none.
      #: () -> bool
      def evidence_kept? = !evidence.nil?

      # The path of each file it points at: its evidence and its write-up.
      #: () -> Array[String]
      def cited_paths = [*evidence&.map { it.fetch("path") }, recorded_at&.path].compact.uniq

      # The commit whose record an audit cited for an earlier first_raised_at, when one did.
      #: () -> String?
      def raised_in = @fields["raised_in"]

      # The one line saying whom it waits on and to decide what, when its deferral says.
      #: () -> String?
      def waits_on = @fields["waits_on"]

      # Since when it has waited on that, when an earlier audit asked it; nil when its own audit did.
      #: () -> String?
      def waits_on_since = @fields["waits_on_since"]

      # Whether its audit left it open, deferred or accepted, for the next full audit to decide.
      #: () -> bool
      def open? = %w[deferred accepted].include?(action)

      # Whether its audit fixed it.
      #: () -> bool
      def fixed? = action == "fixed"

      # This finding pointed at recorded_at, the move from where it pointed appended to its repointed with when and
      # why, or itself when it already points there, so an identical retry writes nothing.
      #: (WriteUpPointer, at: String, reason: String) -> RecordedFinding
      def moved_to(pointer, at:, reason:)
        return self if recorded_at == pointer

        moved = { "from" => @fields["recorded_at"], "to" => pointer.to_h, "at" => at, "reason" => reason }
        RecordedFinding.new(@fields.merge("recorded_at" => pointer.to_h,
                                          "repointed" => [*@fields["repointed"], moved]))
      end

      # The finding as its record's file holds it.
      #: () -> Hash[String, untyped]
      def to_h = @fields
    end
  end
end

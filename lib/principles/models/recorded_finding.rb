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

      # Each change made to it since the full audit that kept it, as field, from, to, at and reason, for the next full
      # audit to see before its record drops them; a repoint's move, which records written by earlier releases keep
      # under repointed, is a change to recorded_at. Nil when none was made.
      #: () -> Array[Hash[String, untyped]]?
      def changes_since_audit
        moves = (@fields["repointed"] || []).map { |moved| { "field" => "recorded_at", **moved } }
        changes = [*moves, *@fields["changed_since_audit"]]
        changes unless changes.empty?
      end

      # This finding pointed at pointer, or written up nowhere for nil, the change kept beside it with when and why;
      # or itself when it already points there, so an identical retry writes nothing.
      #: (WriteUpPointer?, at: String, reason: String) -> RecordedFinding
      def pointed_at(pointer, at:, reason:)
        return self if recorded_at == pointer

        change = { "field" => "recorded_at", "from" => @fields["recorded_at"], "to" => pointer&.to_h, "at" => at,
                   "reason" => reason }
        with(@fields.except("recorded_at").merge(pointer ? { "recorded_at" => pointer.to_h } : {}), change)
      end

      # This finding left open as action, deferred or accepted, its reason the decision's, the change kept beside it,
      # an accepted one waiting on no one; or itself when it already is, so an identical retry writes nothing.
      #: (String, at: String, reason: String) -> RecordedFinding
      def acting(new_action, at:, reason:)
        return self if action == new_action

        change = { "field" => "action", "from" => action, "to" => new_action, "at" => at, "reason" => reason }
        acted = with(@fields.merge("action" => new_action, "reason" => reason), change)
        new_action == "accepted" ? acted.waiting_on(nil, at:, reason:) : acted
      end

      # This finding waiting on line, dated at, or on no one for nil, the change kept beside it with why, or itself
      # when it already waits on line, so an identical retry writes nothing.
      #: (String?, at: String, reason: String) -> RecordedFinding
      def waiting_on(line, at:, reason:)
        return self if waits_on == line

        change = { "field" => "waits_on", "from" => waits_on, "to" => line, "at" => at, "reason" => reason }
        waiting = line ? { "waits_on" => line, "waits_on_since" => at } : {}
        with(@fields.except("waits_on", "waits_on_since").merge(waiting), change)
      end

      # The finding as its record's file holds it.
      #: () -> Hash[String, untyped]
      def to_h = @fields

      private

      # The finding with fields, change appended to the changes kept beside it since its audit.
      #: (Hash[String, untyped], Hash[String, untyped]) -> RecordedFinding
      def with(fields, change)
        RecordedFinding.new(fields.merge("changed_since_audit" => [*@fields["changed_since_audit"], change]))
      end
    end
  end
end

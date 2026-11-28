# typed: strict
# frozen_string_literal: true

require_relative "open_finding"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Every finding the records leave open, deferred or accepted, as one fact the session-start line states: how
    # many deferred wait, and which of them has waited longest.
    class FindingsLeftOpen
      # The findings each record leaves open for the next full audit.
      #: (Array[AuditRecord]) -> FindingsLeftOpen
      def self.of(records) = new(records.flat_map(&:left_open))

      #: (Array[OpenFinding]) -> void
      def initialize(findings)
        @findings = findings
        freeze
      end

      # How many someone should raise, those deferred, how many of them have no waits_on and how many one, and the
      # first raised earliest of them as it has waited until now, or nil when none is deferred: an accepted finding
      # waits on no one by design, so every start counts the same. How long it waited runs from first_raised_at,
      # never from when its waits_on was asked, which a later audit may have given it.
      #: (Time) -> Hash[String, untyped]?
      def waiting_at(now)
        deferred = @findings.select { it.action == "deferred" }
        oldest = deferred.min_by(&:first_raised_time) or return nil

        { "count" => deferred.length, "waiting_on_no_one_named" => deferred.count(&:waiting_on_no_one_named?),
          "waiting_on_someone_named" => deferred.count(&:waiting_on_someone_named?), **oldest.waited_at(now) }
      end
    end
  end
end

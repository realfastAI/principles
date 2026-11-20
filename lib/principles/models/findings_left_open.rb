# typed: strict
# frozen_string_literal: true

require_relative "open_finding"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Every finding the records leave open, deferred or accepted, as one fact the session-start line states: how
    # many wait, and which has waited longest.
    class FindingsLeftOpen
      # The findings each record leaves open for the next full audit.
      #: (Array[AuditRecord]) -> FindingsLeftOpen
      def self.of(records) = new(records.flat_map(&:left_open))

      #: (Array[OpenFinding]) -> void
      def initialize(findings)
        @findings = findings
        freeze
      end

      # How many are open, how many of them are deferred with no waits_on and how many with one, so how many someone
      # should raise, and the first raised earliest of those with one and of all, each as it has waited until now, or
      # nil when none is open. How long it waited runs from first_raised_at, never from when its
      # waits_on was asked, which a later audit may have given it.
      #: (Time) -> Hash[String, untyped]?
      def waiting_at(now)
        oldest = @findings.min_by(&:first_raised_time) or return nil

        named = @findings.select(&:waiting_on_someone_named?)
        unnamed = @findings.count(&:waiting_on_no_one_named?)
        { "count" => @findings.length, "waiting_on_no_one_named" => unnamed,
          "waiting_on_someone_named" => named.length, "to_raise" => named.length + unnamed,
          "oldest_waiting_on_someone" => named.min_by(&:first_raised_time)&.waited_at(now), **oldest.waited_at(now) }
      end
    end
  end
end

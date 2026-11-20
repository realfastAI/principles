# typed: strict
# frozen_string_literal: true

require_relative "../prose_list"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The principles no full audit has completed, as list-member-problems' next_action names them in one line, then
    # each one's audit to start on a line of its own, filled and shell-quoted so the agent types no id.
    class PrinciplesWithNoCompletedAudit
      # audits holds each principle's start-audit command, in the order of ids.
      #: (ids: Array[String], audits: Array[String]) -> void
      def initialize(ids:, audits:)
        @ids = ids
        @audits = audits
        freeze
      end

      # The lack of a completed audit, independent of whether the map is committed or has members yet.
      #: () -> String
      def notice
        one = @ids.length == 1
        carry = one ? "its members carry it" : "their members carry them"
        "No full audit has completed for #{ProseList.new(@ids)} (#{@ids.length} principle#{"s" unless one}), " \
          "so whether #{carry} is unknown."
      end

      #: () -> String
      def to_s
        "#{notice} To start #{@ids.length == 1 ? "one" : "each"}:\n#{@audits.join("\n")}"
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "principles_with_no_completed_audit"

module Principles
  module Views
    # Mapping facts that precede baseline instructions, and their next steps once those instructions are met.
    class MapsNeedingMembersOrAudit
      #: (Invocation, report: Hash[String, untyped], files_to_commit: Hash[String, Array[String]],
      #|  ?waiting: Array[String]) -> void
      def initialize(invocation, report:, files_to_commit:, waiting: [])
        @invocation = invocation
        awaiting = report.fetch("awaiting_first_audit", [])
        @ids = report.fetch("no_completed_audit", []) - awaiting - waiting #: Array[String]
        @empty = report.fetch("empty_maps", []) - waiting #: Array[String]
        @files = files_to_commit
        freeze
      end

      #: () -> String?
      def notice
        PrinciplesWithNoCompletedAudit.new(ids: @ids, audits: []).notice unless @ids.empty?
      end

      #: () -> Array[String]
      def actions
        [*@empty.map { |id| empty_map(id) }, *(@ids - @empty).map { |id| first_audit(id) }]
      end

      private

      #: (String) -> String
      def empty_map(id)
        "#{id} has no members. Add its first member: " \
          "#{@invocation.in_project("add-member", id, usage: "PATH --role ROLE")}"
      end

      #: (String) -> String
      def first_audit(id)
        after = @files.fetch(id, []).empty? ? "To" : "After committing the required files,"
        "#{after} start #{id}'s first full audit: #{@invocation.in_project("start-audit", id)}"
      end
    end
  end
end

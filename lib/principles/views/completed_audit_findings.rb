# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A completed audit's findings by what became of them, as the record it writes holds them: the ids it resolved
    # and those it leaves open, deferred or accepted. Its fields and its default commit subject count the same ids,
    # so they cannot disagree.
    class CompletedAuditFindings
      #: (resolved: Array[String], deferred: Array[String], accepted: Array[String]) -> void
      def initialize(resolved:, deferred:, accepted:)
        @resolved = resolved
        @deferred = deferred
        @accepted = accepted
        freeze
      end

      # The fields as printed.
      #: () -> Hash[String, Array[String]]
      def to_h
        { "resolved_findings" => @resolved, "deferred_findings" => @deferred, "accepted_findings" => @accepted }
      end

      # The default commit subject for principle_id's audit, counting each kind.
      #: (String) -> String
      def subject(principle_id)
        "Audit #{principle_id}: #{@resolved.length} resolved, #{@deferred.length} deferred, " \
          "#{@accepted.length} accepted"
      end
    end
  end
end

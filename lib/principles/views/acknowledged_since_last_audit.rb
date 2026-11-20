# typed: strict
# frozen_string_literal: true

require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The edits to one member acknowledged since the last full audit, as the next full audit's request shows them
    # beside the member, so edits judged one at a time are judged together against the last audited text.
    class AcknowledgedSinceLastAudit
      # last_audited_commit is the last full audit's base commit; acknowledgements are the record's own, oldest
      # first; member_lines its own lines then and now, as a one-member audit shows them. The command that reads every
      # edit since is the member's read_the_change, which every member judged again carries.
      #: (last_audited_commit: String, member_lines: Hash[String, untyped],
      #|  acknowledgements: Array[Hash[String, untyped]]) -> void
      def initialize(last_audited_commit:, member_lines:, acknowledgements:)
        @last_audited_commit = last_audited_commit
        @member_lines = member_lines
        @acknowledgements = acknowledgements
        freeze
      end

      # The fields as the request prints them.
      #: () -> Hash[String, untyped]
      def to_h
        { "last_audited_commit" => @last_audited_commit,
          "acknowledgements" => @acknowledgements.map { |each| each.slice("commit", "reason", "acknowledged_at") },
          "member_lines" => @member_lines,
          "why" => Prompts.text("assess-every-member/judge-acknowledged-edits-together") }
      end
    end
  end
end

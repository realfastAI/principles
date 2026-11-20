# typed: strict
# frozen_string_literal: true

require_relative "../prose_list"
require_relative "invocation"
require_relative "prompts"
require_relative "request_part"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How the meta-principle's full audit states the release of principles its last completed audit ran under beside
    # the one running now, as facts for the agent to judge.
    class PackageSinceLastAuditResult
      # The part this lists, by the name the request prints it under and start-audit --part takes.
      PART = "package_since_last_audit" #: String

      # How the why names each part of principles an upgrade can change, in the order it names them, whatever order
      # the map holds them in.
      PARTS = { "hook" => "the session-start hook", "skill" => "the skill",
                "passage" => "the passage" }.freeze #: Hash[String, String]

      # at_last_audit is the version the last completed audit ran under, or nil when none recorded one; now is the
      # version running now; passage_changed says whether the passage setup proposes changed since, or is nil with
      # nothing to compare. mapped is which of PARTS' keys the map holds. invocation names the setup command the
      # instruction prints.
      #: (Invocation, at_last_audit: String?, now: String, passage_changed: bool?, mapped: Array[String]) -> void
      def initialize(invocation, at_last_audit:, now:, passage_changed:, mapped:)
        @invocation = invocation
        @since = { "version_at_last_audit" => at_last_audit, "version_now" => now,
                   "passage_changed" => passage_changed }.freeze #: Hash[String, untyped]
        @mapped = mapped
        freeze
      end

      # The request's part stating the release since the last audit, with what to do about a change.
      #: () -> RequestPart
      def part
        why = Prompts.text("assess-every-member/judge-the-keeping-under-the-release-since-the-last-audit",
                           mapped: mapped, setup: @invocation.in_project("show-meta-principle-passage"))
        RequestPart.new(shown: { PART => @since.merge("why" => why) }, slots: {})
      end

      private

      # Which of the parts the project maps, as the why's clause after naming all three.
      #: () -> String
      def mapped
        return "none of which this project maps" if @mapped.empty?
        return "all of which this project maps" if @mapped.length == PARTS.length

        named = PARTS.filter_map { |part, words| words if @mapped.include?(part) }
        "of which this project maps only #{ProseList.new(named)}"
      end
    end
  end
end

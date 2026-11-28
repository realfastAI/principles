# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The disposition a correction's template starts each finding with: the text it leaves in each field the agent
    # writes, with %<id>s where it names its finding, and the fields a finding starts from in place of null, as a
    # deferral raised again carries its recorded_at and waits_on.
    class DispositionTemplate
      # placeholders is the text left in each field the agent writes; filled is, by finding id, the fields a
      # disposition starts from in place of null.
      #: (Hash[String, String], ?Hash[String, Hash[String, untyped]]) -> void
      def initialize(placeholders, filled = {})
        @placeholders = placeholders
        @filled = filled
        freeze
      end

      # The reason placeholder, with its %<id>s slot unfilled.
      #: () -> String
      def reason = @placeholders.fetch("reason")

      # The disposition finding starts with.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def for(finding)
        named = @placeholders.transform_values { format(it, id: finding["id"]) }
        { "finding_id" => finding["id"], "action" => named.fetch("action"),
          "reason" => named.fetch("reason"), "changed_members" => [], "changed_map_entries" => [],
          "removed_members" => [], "evidence" => [],
          "reassessment" => nil, "recorded_at" => nil, "waits_on" => nil }.merge(@filled.fetch(finding["id"], {}))
      end
    end
  end
end

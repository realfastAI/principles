# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The audited principle's members that changed during a completed audit, as its result names them: each member
    # added to the map during the audit, which no assessment read, so the next full audit assesses it (T69), and
    # each member whose text changed, after which the next step asks for the principle's audit again.
    class MembersChangedDuringAudit
      #: (?added: Array[String], ?changed: Array[String]) -> void
      def initialize(added: [], changed: [])
        @added = added
        @changed = changed
        freeze
      end

      # Whether any member's text changed during the audit; when none did, nothing asks for a second audit.
      #: () -> bool
      def any? = @changed.any?

      # The fields as printed: the members added, only when there are some.
      #: () -> Hash[String, untyped]
      def to_h = @added.empty? ? {} : { "members_added_awaiting_assessment" => @added }
    end
  end
end

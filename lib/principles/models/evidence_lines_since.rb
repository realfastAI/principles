# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "evidence_item"
require_relative "member_lines"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The lines one evidence item of a prior finding names at the commit the audit that kept the finding was based on,
    # and now, either nil where they cannot be found: what the next full audit's request says of the item. A
    # removed pointer needs finding again and a reworded one judging again, so whether it is found now is said apart
    # from whether it changed.
    class EvidenceLinesSince
      # The lines item names in project at since and now, either nil where it cannot be found or read, so one moved or
      # removed pointer never refuses the request.
      #: (EvidenceItem, since: String, project: Project) -> EvidenceLinesSince
      def self.of(item, since:, project:)
        new(at_base: unless_refused { item.lines_at(project.history, since) },
            now: unless_refused { item.lines_now(project) })
      end

      # What the block reads, or nil when it is refused.
      #: () { () -> Array[String]? } -> Array[String]?
      def self.unless_refused(&)
        yield
      rescue Error
        nil
      end
      private_class_method :unless_refused

      #: (at_base: Array[String]?, now: Array[String]?) -> void
      def initialize(at_base:, now:)
        @at_base = at_base
        @now = now
        freeze
      end

      # Whether its text reads otherwise now than at the base commit, true too when it cannot be found then or now, and
      # whether it is found now.
      #: () -> Hash[String, bool]
      def facts = { "changed_since_last_audit" => changed?, "found_now" => !@now.nil? }

      private

      #: () -> bool
      def changed?
        at_base = @at_base
        now = @now
        return true unless at_base && now

        MemberLines.new(at_baseline: at_base, now: now).changed?
      end
    end
  end
end

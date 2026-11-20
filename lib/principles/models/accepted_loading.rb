# typed: strict
# frozen_string_literal: true

require_relative "loading_facts"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The decision a completed audit accepted on a member's loading, kept in the member's record entry with the
    # member's text hash, as the next full audit shows it beside the member's row. It changed since when
    # what it weighed changed: when the member loads, or the member's own text. A file's size alone moves with every
    # edit elsewhere in a shared file, so it does not count.
    class AcceptedLoading
      # entry is the member's record entry, holding loading_accepted and sha256.
      #: (Hash[String, untyped]) -> void
      def initialize(entry)
        decision = entry.fetch("loading_accepted")
        @reason = decision.fetch("reason") #: String
        @loads = decision.fetch("loads") #: Hash[String, untyped]
        @sha256 = entry.fetch("sha256") #: String
        freeze
      end

      # The reason, and whether what the decision weighed changed since, given the member's loads and hash now; when
      # it did, which of the two changed and the loads accepted, for the agent to see what moved.
      #: (Hash[String, untyped], String?) -> Hash[String, untyped]
      def last_accepted(loads_now, hash_now)
        changed = [("loading" if LoadingFacts.new(@loads) != LoadingFacts.new(loads_now)),
                   ("member_text" if @sha256 != hash_now)].compact
        return { "reason" => @reason, "since_accepted" => "unchanged" } if changed.empty?

        { "reason" => @reason, "since_accepted" => "changed", "changed" => changed, "loads" => @loads }
      end
    end
  end
end

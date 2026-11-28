# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What this tool knew of a member's text when it was mapped, which no audit has assessed: its hash at the commit
    # that mapped it where it is, or, for a plugin member, which no commit holds, the hash its map pinned.
    class MappedBaseline
      # What "since" names each kind as, every one a baseline no audit gave, so a member compared with one alone has
      # never been assessed.
      KINDS = %w[mapping_commit pinned].freeze #: Array[String]

      # The member's hash at the commit that mapped it where it is, from which its automatic history walks.
      #: (String, String) -> MappedBaseline
      def self.at_commit(sha256, commit)
        new(sha256, { "baseline" => "mapping_commit", "commit" => commit }, walks_history: true)
      end

      # A plugin member's pin, its version and hash when add-member read it, which git holds no history of.
      #: (Hash[String, String]) -> MappedBaseline
      def self.pinned(pin)
        new(pin.fetch("sha256"), { "baseline" => "pinned", "version" => pin.fetch("version") }, walks_history: false)
      end

      #: String
      attr_reader :sha256

      # What the baseline was, as a changed member's "since" says.
      #: Hash[String, String]
      attr_reader :since

      #: (String, Hash[String, String], walks_history: bool) -> void
      def initialize(sha256, since, walks_history:)
        @sha256 = sha256
        @since = since.freeze #: Hash[String, String]
        @walks_history = walks_history
        freeze
      end

      # Whether the member's history in git walks back to it.
      #: () -> bool
      def walks_history? = @walks_history
    end
  end
end

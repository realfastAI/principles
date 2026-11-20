# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Where a member may be read at a commit, and the hash of its text there, nil where it cannot be found. A
    # one-member audit takes as the member's baseline the oldest placement that holds the text the audit record
    # vouches for.
    class Placement
      #: String
      attr_reader :commit

      #: Hash[String, untyped]
      attr_reader :reference

      #: String?
      attr_reader :sha256

      # Where the member is at commit, as the Locator MemberFile reads.
      #: () -> Locator
      def locator = Locator.new(reference)

      #: (commit: String, reference: Hash[String, untyped], sha256: String?) -> void
      def initialize(commit:, reference:, sha256:)
        @commit = commit
        @reference = reference
        @sha256 = sha256
        freeze
      end

      # Whether the member's text here is the text whose hash is recorded.
      #: (String?) -> bool
      def holds?(recorded) = !sha256.nil? && sha256 == recorded

      # The paths a change from here to the member at now_path spans, this one first, so a diff over them follows
      # a move.
      #: (String) -> Array[String]
      def paths_to(now_path) = [reference.fetch("path"), now_path].uniq
    end
  end
end

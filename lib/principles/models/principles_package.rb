# typed: strict
# frozen_string_literal: true

require "digest"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The release of principles an audit of the meta-principle ran under: its version, and a digest of the passage
    # it proposes for setup, as printed. An upgrade can change the session-start hook, the skill and the passage,
    # none of which a consuming project maps, so the meta-principle's record keeps this and its next audit states
    # what changed since.
    class PrinciplesPackage
      # The key the passage's digest is kept under. The record keeps its digests by key, as earlier releases kept
      # one for each of two passage forms, so their records stay valid; neither form's key is this one, so a record
      # one of them wrote reads as a passage change once, at the next audit.
      PASSAGE = "entry_file_passage"

      # The release running now, from its version and the passage's text.
      #: (version: String, passage: String) -> PrinciplesPackage
      def self.of(version:, passage:)
        new("version" => version, "passage_sha256" => { PASSAGE => Digest::SHA256.hexdigest(passage) })
      end

      # The release a record kept, or nil when it kept none, as a record of another principle or one an older
      # version wrote does not.
      #: (Hash[String, untyped]?) -> PrinciplesPackage?
      def self.kept(fields) = fields ? new(fields) : nil

      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields.freeze #: Hash[String, untyped]
        freeze
      end

      #: () -> String
      def version = @fields.fetch("version")

      # Whether the passage's text differs from the one earlier proposed, or earlier kept no digest of it.
      #: (PrinciplesPackage) -> bool
      def passage_changed_since?(earlier) = earlier.passage_sha256 != passage_sha256

      # As a record keeps it.
      #: () -> Hash[String, untyped]
      def to_h = @fields

      protected

      #: () -> String?
      def passage_sha256 = @fields.fetch("passage_sha256")[PASSAGE]
    end
  end
end

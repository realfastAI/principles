# typed: strict
# frozen_string_literal: true

require_relative "../data/repository"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The commit first read by one command, including a captured absence. Later history reads share this baseline.
    class CapturedHead
      #: (Data::Repository) -> void
      def initialize(repository)
        @repository = repository
        @commit = nil #: String?
        @read = false #: bool
        @verified = nil #: Data::VerifiedHead?
        @ranges = {} #: Hash[[String?, String], Data::FirstParentRange]
      end

      #: () -> String?
      def commit
        return @commit if @read

        @read = true
        @commit = (@repository.head if @repository.inside?)
      end

      # Permission checks share the command's baseline, refusing disagreement with a prior best-effort read.
      #: (String) -> bool
      def entry?(path) = verified.entry?(path)

      #: (String, String) -> bool
      def entry_at?(revision, path) = verified.entry_at?(revision, path)

      #: (String, String) -> Hash[String, String]?
      def raw_entry_at(revision, path) = verified.raw_entry_at(revision, path)

      # Cache constructed values by owned coordinates; each value certifies its span lazily when queried.
      #: (String?, through: String) -> Data::FirstParentRange
      def first_parent_range(base, through:)
        captured = verified
        lower = base&.dup&.freeze
        upper = through.dup.freeze
        key = [lower, upper].freeze
        @ranges[key] ||= captured.first_parent_range(lower, through: upper)
      end

      #: (String) -> String?
      def first_parent_of(revision) = verified.first_parent_of(revision)

      #: (String, Array[String]) -> Array[String]
      def commits_touching_since(base, paths) = verified.commits_touching_since(base, paths)

      private

      #: () -> Data::VerifiedHead
      def verified
        return @verified if @verified

        captured = @repository.verified_head
        revision = captured.commit
        if @read && @commit != revision
          raise Error.new("git_history_unavailable", "HEAD changed after this command captured its history",
                          "Stop concurrent Git writers and retry this command. No map was created or removed.")
        end
        @commit = revision
        @read = true
        @verified = captured
      end
    end
  end
end

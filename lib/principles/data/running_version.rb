# typed: strict
# frozen_string_literal: true

require_relative "git_command"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The version that is running: what a build stamped, or, in a checkout, the release with the commit it runs
    # from, as RELEASE.g<short sha>. Its caller hands in both from version.rb. The g keeps a development version a
    # RubyGems prerelease even when every character of the sha is a digit.
    class RunningVersion
      # git archive writes the short sha of the commit it archives here, since .gitattributes marks this file
      # export-subst; a checkout keeps the placeholder as written.
      ARCHIVED_COMMIT = "a8698c23" #: String

      #: (?String, release: String, ?built: String?, ?archived_commit: String) -> void
      def initialize(checkout = File.expand_path("../../..", __dir__), release:, built: nil,
                     archived_commit: ARCHIVED_COMMIT)
        @checkout = checkout
        @release = release
        @built = built
        @archived_commit = archived_commit
      end

      #: () -> String
      def to_s
        @built || "#{@release}.g#{commit}"
      end

      private

      # The short sha an archive wrote, which names its commit even inside another repository; else the commit the
      # checkout is at, or "unknown" outside git.
      #: () -> String
      def commit
        return @archived_commit if @archived_commit.match?(/\A\h+\z/)

        sha, ok = GitCommand.new(@checkout).run(%w[rev-parse --short HEAD])
        ok && !sha.strip.empty? ? sha.strip : "unknown"
      end
    end
  end
end

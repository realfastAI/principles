# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The commits that changed one member's own text since this tool last knew it, newest first. The walk goes
    # back from HEAD and stops at the first commit whose text for the member hashes to the baseline, so a fix
    # an audit already took in is never listed. It also stops where the member cannot be found, or at the limit.
    # It reports facts; whether a change is accounted for is the agent's judgement.
    class MemberHistory
      # The most commits listed for one member; the walk says when it stopped here.
      LIMIT = 20

      # commits are the commits that touched the member's file or its map, newest first, up to head, the commit the
      # command reads as HEAD; hash_at gives the member's hash at a revision, or nil where it cannot be found there.
      #: (baseline: String, now: String, commits: Array[Hash[String, String]], head: String,
      #|  hash_at: ^(String) -> String?) -> void
      def initialize(baseline:, now:, commits:, head:, hash_at:)
        @baseline = baseline
        @now = now
        @commits = commits
        @head = head
        @hash_at = hash_at
        freeze
      end

      # The commits that changed the member's text, where and why the walk stopped, and whether the text on disk
      # differs from HEAD.
      #: () -> Hash[String, untyped]
      def to_h
        listed = [] #: Array[Hash[String, String]]
        stopped = walk(listed)
        { "commits" => listed, "stopped_at" => stopped, "uncommitted" => @hash_at.call(@head) != @now }
      end

      private

      #: (Array[Hash[String, String]]) -> Hash[String, String]
      def walk(listed)
        @commits.each do |commit|
          after = @hash_at.call(commit.fetch("sha"))
          return stop("baseline_matched", commit) if after == @baseline
          return { "reason" => "limit" } if listed.length == LIMIT

          stopped = step(listed, commit, after)
          return stopped if stopped
        end
        { "reason" => "history_start" }
      end

      # Lists commit when it changed the member's text, and says why the walk stops at it, if it does: a root
      # commit has no parent, and a parent without the member ends what can be tied to it.
      #: (Array[Hash[String, String]], Hash[String, String], String?) -> Hash[String, String]?
      def step(listed, commit, after)
        root = commit.fetch("root") == "true"
        before = root ? nil : @hash_at.call("#{commit.fetch("sha")}^")
        listed << commit.except("sha", "root") if before != after
        return { "reason" => "history_start" } if root

        stop("member_not_found", commit) unless before
      end

      #: (String, Hash[String, String]) -> Hash[String, String]
      def stop(reason, commit)
        { "reason" => reason, "commit" => commit.fetch("commit") }
      end
    end
  end
end

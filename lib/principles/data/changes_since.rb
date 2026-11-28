# typed: strict
# frozen_string_literal: true

require_relative "git_command"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # What changed in the project after a commit, as git reports it for Repository, with paths relative to the
    # project: the paths the commits up to HEAD changed, the commits that changed some paths, and the renames git
    # detects up to the working tree. Each commit is a revision Repository has checked, so git cannot read it as an
    # option.
    class ChangesSince
      #: (GitCommand) -> void
      def initialize(git)
        @git = git
        freeze
      end

      # Each rename git detects between commit and the working tree, as {"from", "to", "similarity"}; none outside
      # git or when commit is not there, as in a shallow clone.
      #: (String) -> Array[Hash[String, untyped]]
      def renames(commit)
        output, ok = @git.run(["diff", "-M", "-z", "--name-status", "--relative", "--diff-filter=R", commit, "--"])
        return [] unless ok

        output.force_encoding("UTF-8").split("\0").each_slice(3).filter_map do |status, from, to|
          next unless status.to_s.start_with?("R") && from && to

          { "from" => from, "to" => to, "similarity" => status.to_s.delete_prefix("R").to_i }
        end
      end

      # Each path the commits after commit changed, up to HEAD, sorted: added, edited or deleted, and a rename by both
      # its names, since git is asked to detect none.
      #: (String) -> Array[String]
      def paths(commit)
        output, ok = @git.run(["diff", "--name-only", "-z", "--relative", "--no-renames", commit, "HEAD", "--"])
        ok ? output.force_encoding("UTF-8").split("\0").sort : []
      end

      # The commits after commit, up to HEAD, that changed any of paths, newest first, each as its short sha and
      # subject line.
      #: (String, Array[String]) -> Array[Hash[String, String]]
      def commits(commit, paths)
        output, ok = @git.run(["log", "--format=%h%x00%s", "--end-of-options", "#{commit}..HEAD", "--", *paths])
        return [] unless ok

        output.force_encoding("UTF-8").lines.map do |line|
          sha, subject = line.chomp.split("\0", 2)
          { "commit" => sha.to_s, "subject" => subject.to_s }
        end
      end
    end
  end
end

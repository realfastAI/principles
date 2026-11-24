# typed: strict
# frozen_string_literal: true

require_relative "git_command"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Which files in the project's working tree differ from HEAD, or git does not track, as git reports them, with
    # paths relative to the project. Each is asked whether HEAD has a commit at all, since before the first commit
    # nothing is committed and git has no HEAD to diff against.
    class WorkingTreeChanges
      #: (GitCommand) -> void
      def initialize(git)
        @git = git
        freeze
      end

      # Which of paths are untracked or ignored, or differ from HEAD in the index or the working tree. Before the
      # first commit, every path does.
      #: (Array[String], committed: bool) -> Array[String]
      def uncommitted(paths, committed:)
        return [] if paths.empty?
        return paths.uniq.sort unless committed

        changed, = @git.run(["diff", "--name-only", "--relative", "-z", "HEAD", "--", *paths])
        untracked, = @git.run(["ls-files", "--others", "-z", "--", *paths])
        (changed.split("\0") + untracked.split("\0")).uniq.sort
      end

      # Which of paths git does not track and does not ignore. Before the first commit, every path not staged is one.
      #: (Array[String]) -> Array[String]
      def untracked_excluding_ignored(paths)
        return [] if paths.empty?

        output, = @git.run(["ls-files", "--others", "--exclude-standard", "-z", "--", *paths])
        output.split("\0").sort
      end

      # Which of paths git does not track, ignored or not. Unlike untracked_excluding_ignored, it names an ignored
      # file too, since git holds it no more than an untracked one.
      #: (Array[String]) -> Array[String]
      def untracked_including_ignored(paths)
        return [] if paths.empty?

        output, = @git.run(["ls-files", "--others", "-z", "--", *paths])
        output.split("\0").sort
      end

      # Every file in the project that differs from HEAD, is gone since it, or is untracked, sorted. Unlike
      # uncommitted, it leaves ignored files out: it is asked about the whole project, where an ignored file is
      # one the owner chose to keep out of git, while uncommitted is asked about named members, which an audit
      # needs committed. Before the first commit, every file not ignored is one.
      #: (committed: bool) -> Array[String]
      def changed_files(committed:)
        changed, = committed ? @git.run(["diff", "--name-only", "--relative", "-z", "HEAD"]) : [""]
        untracked, = @git.run(["ls-files", "--others", "--exclude-standard", "-z"])
        (changed.split("\0") + untracked.split("\0")).uniq.sort
      end
    end
  end
end

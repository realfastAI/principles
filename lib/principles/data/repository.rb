# typed: strict
# frozen_string_literal: true

require_relative "git_command"
require_relative "verified_head"
require_relative "first_parent_log"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The git repository holding the project, if there is one. This tool only reads it: the commit at HEAD,
    # which paths differ from it, and a file's text at a commit. git's own messages are kept off this tool's
    # output.
    class Repository
      # The revisions this tool hands git: HEAD or a full commit sha (SHA-1 or SHA-256), optionally its first parent.
      # None can be read as an option or a wider revision expression. commit_of alone takes a revision the agent names,
      # which git reads after --end-of-options, and gives back the full sha every other read takes.
      REVISION = /\A(?:HEAD|\h{40}(?:\h{24})?)\^?\z/ #: Regexp

      # The revisions among those that always name one commit: a full sha, optionally its first parent.
      FULL_SHA = /\A\h{40}(?:\h{24})?\^?\z/ #: Regexp

      #: (String) -> void
      def initialize(root)
        @root = root
        @git = GitCommand.new(root) #: GitCommand
        @texts = {} #: Hash[[String, String], String?]
        @log = FirstParentLog.new(@git) #: FirstParentLog
      end

      # A strict permission snapshot; legacy best-effort readers keep their existing behavior.
      #: () -> VerifiedHead
      def verified_head = VerifiedHead.new(@root)

      # Whether the project is inside a git work tree.
      #: () -> bool
      def inside?
        output, ok = git(["rev-parse", "--is-inside-work-tree"])
        ok && output.strip == "true"
      end

      # The user name git commits as here, or nil when none is set.
      #: () -> String?
      def user_name
        name, ok = git(["config", "user.name"])
        ok && !name.strip.empty? ? name.strip : nil
      end

      # The full sha of the last commit that changed path, or nil outside git or when no commit has.
      #: (String) -> String?
      def last_commit(path)
        sha, ok = git(["log", "-1", "--format=%H", "--", path])
        ok && !sha.strip.empty? ? sha.strip : nil
      end

      # Whether path, relative to the project, is absent from the working tree.
      #: (String) -> bool
      def absent?(path)
        !File.exist?(File.join(@root, path))
      end

      # Each rename git detects between commit and the working tree, as {"from", "to", "similarity"}, with paths
      # relative to the project; none outside git or when commit is not there, as in a shallow clone.
      #: (String) -> Array[Hash[String, untyped]]
      def renames_since(commit)
        output, ok = git(["diff", "-M", "-z", "--name-status", "--relative", "--diff-filter=R", revision(commit), "--"])
        return [] unless ok

        output.force_encoding("UTF-8").split("\0").each_slice(3).filter_map do |status, from, to|
          next unless status.to_s.start_with?("R") && from && to

          { "from" => from, "to" => to, "similarity" => status.to_s.delete_prefix("R").to_i }
        end
      end

      # The full sha at HEAD, or nil outside git or before the first commit.
      #: () -> String?
      def head
        sha, ok = git(["rev-parse", "--verify", "--quiet", "HEAD"])
        ok && !sha.strip.empty? ? sha.strip : nil
      end

      # The full sha of the commit revision names, as git resolves it, or nil when it names none. The revision is the
      # agent's own, so git reads it after --end-of-options, never as an option.
      #: (String) -> String?
      def commit_of(revision)
        sha, ok = git(["rev-parse", "--verify", "--quiet", "--end-of-options", "#{revision}^{commit}"])
        ok && !sha.strip.empty? ? sha.strip : nil
      end

      # Each path the commits after commit changed, up to HEAD, sorted and relative to the project: added, edited or
      # deleted, and a rename by both its names, since git is asked to detect none. commit is a full sha, as commit_of
      # gives it, so git cannot read it as an option.
      #: (String) -> Array[String]
      def changed_since(commit)
        output, ok = git(["diff", "--name-only", "-z", "--relative", "--no-renames", revision(commit), "HEAD", "--"])
        ok ? output.force_encoding("UTF-8").split("\0").sort : []
      end

      # Which of paths, relative to the project, are untracked or ignored, or differ from HEAD in the index
      # or the working tree. Before the first commit, every path does.
      #: (Array[String]) -> Array[String]
      def uncommitted(paths)
        return [] if paths.empty?
        return paths.uniq.sort unless head

        changed, = git(["diff", "--name-only", "--relative", "-z", "HEAD", "--", *paths])
        untracked, = git(["ls-files", "--others", "-z", "--", *paths])
        (changed.split("\0") + untracked.split("\0")).uniq.sort
      end

      # Which of paths, relative to the project, git does not track and does not ignore. Before the first
      # commit, every path not staged is one.
      #: (Array[String]) -> Array[String]
      def untracked(paths)
        return [] if paths.empty?

        output, = git(["ls-files", "--others", "--exclude-standard", "-z", "--", *paths])
        output.split("\0").sort
      end

      # Which of paths, relative to the project, git does not track, ignored or not. Unlike untracked, it names an
      # ignored file too, since git holds it no more than an untracked one.
      #: (Array[String]) -> Array[String]
      def not_tracked(paths)
        return [] if paths.empty?

        output, = git(["ls-files", "--others", "-z", "--", *paths])
        output.split("\0").sort
      end

      # Every path in the project git tracks, as git spells it, sorted, so a path a disk that folds case opens under
      # another spelling can be told apart; none outside git.
      #: () -> Array[String]
      def tracked_files
        output, ok = git(["ls-files", "-z"])
        ok ? output.force_encoding("UTF-8").split("\0").sort : []
      end

      # Every file in the project that differs from HEAD, is gone since it, or is untracked, sorted. Unlike
      # uncommitted, it leaves ignored files out: it is asked about the whole project, where an ignored file is
      # one the owner chose to keep out of git, while uncommitted is asked about named members, which an audit
      # needs committed. Before the first commit, every file not ignored is one.
      #: () -> Array[String]
      def changed_files
        changed, = head ? git(["diff", "--name-only", "--relative", "-z", "HEAD"]) : [""]
        untracked, = git(["ls-files", "--others", "--exclude-standard", "-z"])
        (changed.split("\0") + untracked.split("\0")).uniq.sort
      end

      # path's text at commit, frozen, or nil when the commit does not hold it. Text at a full sha never changes, so
      # git is asked for it once; HEAD moves with each commit, so it is asked every time.
      #: (String, String) -> String?
      def text_at(commit, path)
        return read_text_at(commit, path) unless FULL_SHA.match?(commit)

        @texts[[commit, path]] ||= read_text_at(commit, path)
      end

      # The commits after commit, up to HEAD, that changed any of paths, newest first, each as its short sha and
      # subject line.
      #: (String, Array[String]) -> Array[Hash[String, String]]
      def commits_since(commit, paths)
        output, ok = git(["log", "--format=%h%x00%s", "--end-of-options", "#{revision(commit)}..HEAD", "--", *paths])
        return [] unless ok

        output.force_encoding("UTF-8").lines.map do |line|
          sha, subject = line.chomp.split("\0", 2)
          { "commit" => sha.to_s, "subject" => subject.to_s }
        end
      end

      # Every commit on up_to's first-parent line, HEAD's unless given, that changed any of paths, newest first, each
      # as its full and short sha, subject line, author date and whether it is a root commit ("true" or "false"); none
      # outside git. since leaves out since and every commit before it. The list and each commit are frozen. Between
      # full shas the list never changes, so git is asked for it once, and a refusal, as for a sha the clone lacks, is
      # kept too, since asking again would be refused again; HEAD moves with each commit, so it is asked every time.
      #: (Array[String], ?since: String?, ?up_to: String) -> Array[Hash[String, String]]
      def commits_touching(paths, since: nil, up_to: "HEAD")
        range = since ? "#{revision(since)}..#{revision(up_to)}" : revision(up_to)
        @log.touching(range, paths, kept: [since || up_to, up_to].all? { FULL_SHA.match?(it) })
      end

      private

      #: (String, String) -> String?
      def read_text_at(commit, path)
        text, ok = git(["show", "--end-of-options", "#{revision(commit)}:./#{path}"])
        ok ? text.force_encoding("UTF-8").freeze : nil
      end

      # commit, once it is known to be a revision this tool hands git. Answers are checked against their schema
      # first, so reaching here with anything else is a defect in this tool, not a refusal for the agent.
      #: (String) -> String
      def revision(commit)
        raise ArgumentError, "not a revision this tool reads: #{commit.inspect}" unless REVISION.match?(commit)

        commit
      end

      #: (Array[String]) -> [String, bool]
      def git(arguments) = @git.run(arguments)
    end
  end
end

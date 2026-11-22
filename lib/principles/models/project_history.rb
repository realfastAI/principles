# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../data/repository"
require_relative "../data/project_files"
require_relative "../data/principles_subfolder"
require_relative "project_at_commit"
require_relative "commits_brought_in"
require_relative "uncommitted_files"
require_relative "captured_head"
require_relative "tracked_paths"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What an audit needs from the project's git history, read through Data::Repository: the commit an audit
    # is based on, each member as that commit holds it, and what changed since. Outside git there is no
    # history, and an audit has no base commit. A path that is a symbolic link, or lies below one, is read at
    # each commit in the file its links lead to, and whether it is committed, and which commits touched it, cover
    # every link on the way, since git holds a link as its target's name. uncommitted_outside alone asks by
    # the paths given: start-audit asks it only once base_commit found every file they lead to committed.
    class ProjectHistory
      # This tool's folder as git names a folder, now and under its earlier name.
      OWN_FOLDERS = [Data::PrinciplesSubfolder::FOLDER, Data::PrinciplesSubfolder::EARLIER_FOLDER]
                    .map { |folder| "#{folder}/" }.freeze #: Array[String]

      #: (Data::Repository, Data::ProjectFiles) -> void
      def initialize(repository, files)
        @repository = repository
        @files = files
        @head = CapturedHead.new(repository) #: CapturedHead
        @tracked_paths = nil #: TrackedPaths?
      end

      # Every path git tracks, as git spells it, read once for the command; none outside git.
      #: () -> TrackedPaths
      def tracked_paths = @tracked_paths ||= TrackedPaths.new(@repository.tracked_files)

      # Which of paths, and of the links and files they lead through, git does not track and does not ignore, which
      # an audit refuses as members until committed. nil outside git, where nothing is checked.
      #: (Array[String]) -> Array[String]?
      def untracked_excluding_ignored(paths)
        @repository.untracked_excluding_ignored(through_links(paths)) if @repository.inside?
      end

      # Whether git tracks path and every file its links lead to, so a fresh clone finds its text; an ignored file is
      # not tracked either. True outside git, where nothing is checked.
      #: (String) -> bool
      def tracks?(path) = !@repository.inside? || @repository.untracked_including_ignored(through_links([path])).empty?

      # Whether the project is in git, so it has a history at all.
      #: () -> bool
      def inside_git? = @repository.inside?

      # The full sha of the commit revision names, which a survey of the commits after it starts from. Refuses outside
      # git, where there are no commits, and a revision git resolves to no commit.
      #: (String) -> String
      def commit_named(revision)
        unless @repository.inside?
          raise Error.new("range_needs_git", "--commits-after needs git, to read the commits after #{revision}",
                          "To survey every candidate instead, run it without --commits-after.")
        end

        @repository.commit_of(revision) or
          raise Error.new("unknown_revision", "git resolves #{revision} to no commit",
                          "Name a commit git knows, such as a sha from git log, a branch or HEAD~3.")
                     .including("revision" => revision)
      end

      # Each file the commits after commit, a full sha, changed up to HEAD that the project still holds.
      #: (String) -> Array[String]
      def changed_after(commit) = @repository.changed_since(commit).select { |path| @files.file?(path) }

      # The project's files, other than paths, that differ from HEAD or are untracked, ignored ones aside; nil
      # outside git or when there are none. A check and an answer's evidence read them as they are now.
      #: (Array[String]) -> Array[String]?
      def uncommitted_outside(paths)
        return unless @repository.inside?

        outside = @repository.changed_files - paths
        outside unless outside.empty?
      end

      # Refuses a write-up's path while it, or a file its links lead to, differs from HEAD: the record is committed
      # pointing at it, so a fresh clone would find nothing there. Nothing outside git.
      #: (String) -> void
      def refuse_uncommitted_write_up(path)
        UncommittedFiles.new(uncommitted([path])).refuse_write_up(path) if @repository.inside?
      end

      # The commit an audit of id is based on: HEAD, refused while any of files, or a file their links lead to,
      # differs from it. nil outside git.
      #: (String, Array[String]) -> String?
      def base_commit(id, files)
        return unless @repository.inside?

        UncommittedFiles.new(uncommitted(files)).refuse_audit(id)
        head
      end

      # The project as commit holds it.
      #: (String) -> ProjectAtCommit
      def at(commit) = ProjectAtCommit.new(@repository, @files, commit)

      # The rename git detects for path, a file absent from the working tree, as {"to", "similarity",
      # "deleted_in"}: the last commit that touched path, or nil while the move is not yet committed. It is
      # git's similarity match, which can pair a deleted file with an unrelated similar one, so the agent checks
      # it. nil outside git, for a file that exists, or when git detects none.
      #: (String) -> Hash[String, untyped]?
      def rename_of(path)
        return unless @repository.inside? && @repository.absent?(path)

        deleted_in = @repository.text_at("HEAD", path) ? nil : @repository.last_commit(path)
        base = deleted_in ? "#{deleted_in}^" : "HEAD"
        found = @repository.renames_since(base).find { |each| each["from"] == path } or return nil
        found.slice("to", "similarity").merge("deleted_in" => deleted_in)
      end

      # Which of paths, and of the links and files they lead through, differ from HEAD, or are not yet committed.
      #: (Array[String]) -> Array[String]
      def uncommitted(paths)
        @repository.uncommitted(through_links(paths))
      end

      # Which of paths name a file in the project now, so a file deleted since an audit cited it is not committed as a
      # deletion.
      #: (Array[String]) -> Array[String]
      def existing(paths) = paths.select { |path| @files.file?(path) }

      # The commit HEAD named when this history first asked, kept for the rest of the command, so a commit landing
      # while it runs leaves no read at one commit and the next at another; nil outside git. A history serves
      # one command at most, so the next command sees the new commit.
      #: () -> String?
      def head = @head.commit

      #: () -> CapturedHead
      def captured_head = @head

      # The commits after commit that changed path, a link on the way to it or the file they lead to, newest
      # first.
      #: (String, String) -> Array[Hash[String, String]]
      def commits_since(commit, path)
        @repository.commits_since(commit, through_links([path]))
      end

      # Every commit on the first-parent line of head, the HEAD this history first named, that changed any of paths,
      # newest first; with since, only those after it.
      #: (Array[String], ?since: String?) -> Array[Hash[String, String]]
      def commits_touching(paths, since: nil)
        @repository.commits_touching(through_links(paths), since: since, up_to: head || "HEAD")
      end

      # The commits after commit, up to HEAD, that one move of HEAD brought in, whatever they changed.
      #: (String) -> CommitsBroughtIn
      def commits_brought_in(commit)
        CommitsBroughtIn.new(@repository.commits_since(commit, []).map { |each| each.fetch("commit") })
      end

      # Whether any commit after commit changed this tool's own folder, under its name now or its earlier one, or one
      # of paths, a link on the way to one or the file they lead to: the only changes that could make a command
      # refuse that did not refuse before (review R8).
      #: (String, Array[String]) -> bool
      def touched_since?(commit, paths)
        !@repository.commits_since(commit, [*OWN_FOLDERS, *through_links(paths)]).empty?
      end

      # Whether one raw entry belongs to the permission-specific captured head.
      #: (String) -> bool
      def entry_at_head?(path) = @head.entry?(path)

      #: (String, Array[String]) -> Array[String]
      def commits_touching_since(base, paths) = @head.commits_touching_since(base, paths)

      #: (String, String) -> bool
      def entry_at?(revision, path) = @head.entry_at?(revision, path)

      private

      # paths, each with the links on the way to it and the file they lead to, once each.
      #: (Array[String]) -> Array[String]
      def through_links(paths)
        paths.flat_map { |path| @files.text_paths(path) }.uniq
      end
    end
  end
end

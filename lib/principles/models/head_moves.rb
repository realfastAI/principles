# typed: strict
# frozen_string_literal: true

require_relative "after_commit_input"
require_relative "../data/head_reflog"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Which repositories' HEAD a shell call moved by committing, each named once, in the order the call's
    # directories name them, with the commit HEAD named before the move: what report-after-commit reports on. A
    # checkout or a reset moves HEAD to commits that exist already, so neither is named; the next session start
    # shows any change there. A project never mapped, under the folder's name now or its earlier one, is not named,
    # nor a repository other than the session's project's, such as a scratch clone; its worktrees are named.
    class HeadMoves
      # One repository's move: its root, and the full sha HEAD named before it.
      class Move
        #: String
        attr_reader :root, :before

        #: (root: String, before: String) -> void
        def initialize(root:, before:)
          @root = root
          @before = before
          freeze
        end
      end

      # The reflog subjects of moves that bring in no new commit.
      NOT_A_COMMIT = /\A(?:checkout|reset):/ #: Regexp

      # What git says of a directory on this machine.
      GIT_AT = ->(directory) { Data::HeadReflog.new(directory) } #: ^(String) -> untyped

      # git_at gives what git says of a directory, as Data::HeadReflog does.
      #: (AfterCommitInput, ?^(String) -> untyped) -> void
      def initialize(input, git_at = GIT_AT)
        @input = input
        @git_at = git_at
        freeze
      end

      #: () -> Array[Move]
      def to_a
        project = nil #: String?
        repositories.filter_map do |root, git|
          before = git.mapped? && before_the_move(git)
          next unless before && git.common_dir == (project ||= the_sessions_repository)

          Move.new(root:, before:)
        end
      end

      private

      # The git folder of the session's project, which its worktrees share and a clone does not, or a value no
      # repository's matches when the session's directory is outside git. Asked only once a repository moved, so a
      # call that committed nothing costs no more git.
      #: () -> String
      def the_sessions_repository = @git_at.call(@input.session_directory).common_dir || ""

      # Each repository the call's directories are in, once, in their order: what git says of it, by its root.
      #: () -> Hash[String, untyped]
      def repositories
        @input.directories.each_with_object({}) do |directory, found|
          git = @git_at.call(directory)
          root = git.toplevel
          found[root] ||= git if root
        end
      end

      # The commit HEAD named before it moved during the call, or nil when it did not move then, or moved to no
      # new commit. Without a reflog, HEAD's committer time stands in, and the commit before HEAD starts the range.
      #: (untyped) -> String?
      def before_the_move(git)
        moved, subject = git.last_move
        return (git.commit("HEAD^") if git.committed_at.to_i >= @input.started) unless moved
        return if moved < @input.started || subject.to_s.match?(NOT_A_COMMIT)

        git.commit("HEAD@{1}")
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "git_command"
require_relative "first_parent_range"
require_relative "committed_tree"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # A permission-specific captured Git head, distinct from best-effort history display. Absence needs positive
    # unborn evidence or inspectable physical ancestry without repository markers; failed access never grants it.
    class VerifiedHead
      OVERRIDES = %w[GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR].freeze #: Array[String]
      SHA = /\A\h{40}(?:\h{24})?\z/ #: Regexp

      #: (String) -> void
      def initialize(root)
        @root = root
        @git = GitCommand.new(root) #: GitCommand
        @commit = nil #: String?
        @read = false #: bool
      end

      #: () -> String?
      def commit
        return @commit if @read

        @commit = capture&.freeze
        @read = true
        @commit
      end

      # A raw tree entry counts even when it is not readable JSON, a tree or a dangling link. Paths remain relative
      # to the project, not the repository top; literal pathspecs come from GitCommand.
      #: (String) -> bool
      def entry?(path)
        sha = commit or return false
        entry_at?(sha, path)
      end

      #: (String, String) -> bool
      def entry_at?(revision, path) = CommittedTree.new(@git, revision, unavailable).entry?(path)

      #: (String, String) -> Hash[String, String]?
      def raw_entry_at(revision, path) = CommittedTree.new(@git, revision, unavailable).raw_entry(path)

      # This span proves only base to through; its upper's membership in captured HEAD needs a separate proof.
      #: (String?, through: String) -> FirstParentRange
      def first_parent_range(base, through:) = FirstParentRange.new(@git, base, through)

      #: (String) -> String?
      def first_parent_of(revision)
        raise unavailable unless SHA.match?(revision)

        output, status = @git.run_with_status(["cat-file", "commit", revision])
        raise unavailable unless status&.zero?

        parent_names(output, revision.length).first&.freeze
      end

      #: (String, Array[String]) -> Array[String]
      def commits_touching_since(base, paths)
        head = commit or raise unavailable
        FirstParentRange.new(@git, base, head).touching(paths)
      end

      private

      #: (String, Integer) -> Array[String]
      def parent_names(output, name_length)
        header, message = output.b.split("\n\n", 2)
        rows = header.to_s.lines.map(&:chomp)
        tree = rows.first.to_s
        raise unavailable unless message && tree.start_with?("tree ")

        parents = rows.grep(/\Aparent\b/).map { it.delete_prefix("parent ") }
        confirm_object_names([tree.delete_prefix("tree "), *parents], name_length)

        parents
      end

      #: (Array[String], Integer) -> void
      def confirm_object_names(names, name_length)
        raise unavailable unless names.all? { SHA.match?(it) && it.length == name_length }
      end

      #: () -> String?
      def capture
        output, status = @git.run_with_status(["rev-parse", "--is-inside-work-tree"])
        return inside_commit if status&.zero? && output.strip == "true"
        return nil if status == 128 && physically_outside?

        raise unavailable
      end

      #: () -> String?
      def inside_commit
        output, status = @git.run_with_status(["rev-parse", "--verify", "--quiet", "HEAD^{commit}"])
        return output.strip if status&.zero? && SHA.match?(output.strip)

        raise unavailable unless status == 1

        unborn_commit
      end

      # Only a symbolic branch whose ref is positively absent certifies an unborn work tree.
      #: () -> nil
      def unborn_commit
        branch, symbolic = @git.run_with_status(["symbolic-ref", "--quiet", "HEAD"])
        raise unavailable unless symbolic&.zero? && branch.start_with?("refs/heads/")

        _, exists = @git.run_with_status(["show-ref", "--exists", branch.strip])
        raise unavailable unless exists == 2

        nil
      end

      # Git performs positive discovery. This only proves a failed discovery has no physical repository to hide;
      # ambiguous metadata, explicit discovery overrides and filesystem errors are not evidence of absence.
      #: () -> bool
      def physically_outside?
        return false if OVERRIDES.any? { |name| ENV[name] }

        directory = File.realpath(@root)
        loop do
          return false if repository_marker?(directory)

          parent = File.dirname(directory)
          return true if parent == directory

          directory = parent
        end
      rescue SystemCallError
        false
      end

      #: (String) -> bool
      def repository_marker?(directory)
        return true if entry_exists?(File.join(directory, ".git"))

        %w[HEAD objects refs].count { |name| entry_exists?(File.join(directory, name)) } >= 2
      end

      #: (String) -> bool
      def entry_exists?(path)
        File.lstat(path)
        true
      rescue Errno::ENOENT
        false
      end

      #: () -> Error
      def unavailable
        Error.new("git_history_unavailable", "Git history could not be verified safely",
                  "Restore access to a healthy Git work tree and retry. Before the first commit, make an initial " \
                  "commit or use Git supporting show-ref --exists. No map was created or removed.")
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "git_command"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The commits on a first-parent line that changed any of some paths, as git log gives them, newest first, each as
    # its full and short sha, subject line, author date and whether it is a root commit ("true" or "false"). The list
    # and each commit are frozen, and a list asked to be kept is read from git once, a refusal included.
    class FirstParentLog
      # Each commit's full and short sha, subject line, author date and parents, as git log prints them.
      FORMAT = "%H%x00%h%x00%s%x00%aI%x00%P" #: String

      # What read_ahead's log starts each commit's full sha with: a byte no sha holds.
      START = "\x01" #: String

      # A token of read_ahead's log that starts a commit.
      STARTS_A_COMMIT = /\A\x01\h{40}(?:\h{24})?\z/ #: Regexp

      #: (GitCommand) -> void
      def initialize(git)
        @git = git
        @kept = {} #: Hash[[String, Array[String]], Array[Hash[String, String]]]
      end

      # The commits in range, a revision range Repository has checked, that changed any of paths; kept, when range
      # always names the same commits, so git is not asked again.
      #: (String, Array[String], kept: bool) -> Array[Hash[String, String]]
      def touching(range, paths, kept:)
        return read(range, paths) unless kept

        @kept[[range, paths.dup.freeze]] ||= read(range, paths)
      end

      # Reads the commits in range, one that always names the same commits, touching each of path_sets in one git log,
      # and keeps each set's as touching keeps it: each log walks the whole history, whatever it lists. A merge counts
      # by its changes from its first parent, as git log --first-parent counts it. When git cannot list them so, none
      # is kept, and touching asks git for each set.
      #: (String, Array[Array[String]]) -> void
      def read_ahead(range, path_sets)
        output, ok = @git.run(["log", "--first-parent", "--diff-merges=first-parent", "--no-renames", "--relative",
                               "--name-only", "-z", "--format=#{START}#{FORMAT}", "--end-of-options", range, "--",
                               *path_sets.flatten.uniq])
        return unless ok

        changed = changes(output)
        path_sets.each do |paths|
          @kept[[range, paths.dup.freeze]] ||=
            changed.filter_map { |commit, names| commit if names.any? { |name| within?(name, paths) } }.freeze
        end
      end

      private

      #: (String, Array[String]) -> Array[Hash[String, String]]
      def read(range, paths)
        output, ok = @git.run(["log", "--first-parent", "--format=#{FORMAT}", "--end-of-options", range, "--", *paths])
        (ok ? output.force_encoding("UTF-8").lines.map { |line| commit(line.chomp) } : []).freeze
      end

      # Each commit in output, the log read_ahead asks git for, with the names it changed.
      #: (String) -> Array[[Hash[String, String], Array[String]]]
      def changes(output)
        tokens = output.force_encoding("UTF-8").split("\0")
        tokens.slice_before { |token| STARTS_A_COMMIT.match?(token) }.map do |fields|
          names = fields.drop(5).map { |name| name.delete_prefix("\n") }.reject(&:empty?)
          [commit(fields.first(5).join("\0").delete_prefix(START)), names]
        end
      end

      # Whether name is one of paths, or lies in one of them, as git reads a literal pathspec.
      #: (String, Array[String]) -> bool
      def within?(name, paths)
        paths.any? { |path| name == path || name.start_with?("#{path.delete_suffix("/")}/") }
      end

      # One commit as FORMAT prints it, frozen.
      #: (String) -> Hash[String, String]
      def commit(line)
        sha, short, subject, authored_at, parents = line.split("\0", 5)
        { "sha" => sha.to_s, "commit" => short.to_s, "subject" => subject.to_s, "authored_at" => authored_at.to_s,
          "root" => parents.to_s.empty?.to_s }.freeze
      end
    end
  end
end

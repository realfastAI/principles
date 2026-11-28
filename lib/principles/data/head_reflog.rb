# typed: strict
# frozen_string_literal: true

require_relative "git_command"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # What git says of HEAD in the repository holding one directory, as report-after-commit asks it after each shell
    # call: the repository's root and git folder, whether this tool mapped it, when its HEAD reflog was last written
    # and the subject of that move, HEAD's committer time, and the full sha of a revision. Each is nil where git cannot
    # say.
    class HeadReflog
      # The folders a mapped project holds its maps in: the folder's name now, and its earlier one.
      MAPS_FOLDERS = %w[.principles .memeplex].freeze #: Array[String]
      # How much of a reflog's end holds its last entry: a subject runs to one line, of a commit's first line.
      TAIL_BYTES = 8192

      #: (String) -> void
      def initialize(directory)
        @git = GitCommand.new(directory) #: GitCommand
        freeze
      end

      # The root of the work tree holding the directory, or nil outside git.
      #: () -> String?
      def toplevel = read(["rev-parse", "--show-toplevel"])

      # The repository's git folder, which each of its worktrees shares and a clone does not, with every symbolic link
      # resolved, or nil outside git.
      #: () -> String?
      def common_dir
        folder = read(["rev-parse", "--path-format=absolute", "--git-common-dir"]) or return
        File.realpath(folder)
      rescue SystemCallError
        nil
      end

      # Whether this tool's folder is at the root.
      #: () -> bool
      def mapped?
        root = toplevel or return false
        MAPS_FOLDERS.any? { File.directory?(File.join(root, it)) }
      end

      # When this work tree's HEAD reflog was last written, to the second, and the subject of its last entry, or nil
      # when it keeps none.
      #: () -> [Integer, String]?
      def last_move
        path = read(["rev-parse", "--path-format=absolute", "--git-path", "logs/HEAD"])
        return unless path && File.file?(path)

        [File.mtime(path).to_i, last_line(path).chomp.split("\t", 2)[1].to_s]
      rescue SystemCallError
        nil
      end

      # HEAD's committer time, in seconds, or nil when there is no HEAD.
      #: () -> Integer?
      def committed_at = read(["log", "-1", "--format=%ct", "HEAD"])&.to_i

      # The full sha revision names, or nil when it names no commit.
      #: (String) -> String?
      def commit(revision) = read(["rev-parse", "--verify", "--quiet", "--end-of-options", "#{revision}^{commit}"])

      private

      # The last line of the file at path, read from its end, since a reflog grows with every move.
      #: (String) -> String
      def last_line(path)
        File.open(path) do |file|
          file.seek([file.size - TAIL_BYTES, 0].max)
          file.read.to_s.lines.last.to_s
        end
      end

      #: (Array[String]) -> String?
      def read(arguments)
        output, ok = @git.run(arguments)
        text = output.strip
        text if ok && !text.empty?
      end
    end
  end
end

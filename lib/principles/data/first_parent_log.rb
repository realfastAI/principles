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

      private

      #: (String, Array[String]) -> Array[Hash[String, String]]
      def read(range, paths)
        output, ok = @git.run(["log", "--first-parent", "--format=%H%x00%h%x00%s%x00%aI%x00%P", "--end-of-options",
                               range, "--", *paths])
        (ok ? commits(output).each(&:freeze) : []).freeze
      end

      # Each commit in output, the log read asks git for.
      #: (String) -> Array[Hash[String, String]]
      def commits(output)
        output.force_encoding("UTF-8").lines.map do |line|
          sha, short, subject, authored_at, parents = line.chomp.split("\0", 5)
          { "sha" => sha.to_s, "commit" => short.to_s, "subject" => subject.to_s, "authored_at" => authored_at.to_s,
            "root" => parents.to_s.empty?.to_s }
        end
      end
    end
  end
end

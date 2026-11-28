# typed: strict
# frozen_string_literal: true

require_relative "git_command"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Which local branches would bring paths into the project if they merged, as git reports it for Repository: each
    # path that a branch's commits not on HEAD add or change, and do not then delete, with paths relative to the
    # project. One git log reads only those commits, limited to the paths, so a project with many branches pays only
    # for commits no merge has brought in yet. git names each commit by one branch that reaches it, so of branches
    # sharing the commit that brings a path in, one is named.
    class BranchesBringingIn
      # What starts each commit's record in the log: the branch git reached it by.
      RECORD = "\x01"

      #: (GitCommand) -> void
      def initialize(git)
        @git = git
        freeze
      end

      # Each of paths a branch brings in, with the branches that do, sorted; none outside git, or for no paths.
      #: (Array[String]) -> Hash[String, Array[String]]
      def of(paths)
        return {} if paths.empty?

        output, ok = @git.run(["log", "--branches", "--not", "HEAD", "--source", "--no-renames", "--name-status",
                               "--relative", "-z", "--format=%x01%S", "--", *paths])
        return {} unless ok

        newest(output.force_encoding("UTF-8")).reject { |_, status| status == "D" }.keys
                                              .group_by(&:last).transform_values { it.map(&:first).sort }
      end

      private

      # Each branch and path the log names, with the status of the newest commit of that branch to change the path:
      # the log lists commits newest first, each its branch, then each status and path.
      #: (String) -> Hash[[String, String], String]
      def newest(log)
        found = {} #: Hash[[String, String], String]
        log.split(RECORD).drop(1).each do |record|
          branch, *fields = record.split("\0")
          fields.each_slice(2) { |status, path| found[[branch.to_s, path.to_s]] ||= status.to_s.strip }
        end
        found
      end
    end
  end
end

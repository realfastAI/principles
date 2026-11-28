# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "project_history"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The files that broken members name but that cannot be read, each with the members it held, so one rename
    # reads as one new path to find. Each member still takes its own move: whether every one of them
    # landed in the same place is the agent's judgement. Beside a path, git_detected_rename gives any rename git
    # detects for it, which the agent checks before using.
    class MissingFiles
      # How to read a git_detected_rename, wherever this tool gives one beside a missing file.
      RENAME_MATCH = "check before you use it: its similarity is git's percentage of the old file found in the " \
                     "new one, and 50 is git's default cut-off for calling it a rename."
      # What a broken_members repair says of missing_files, so each refusal says it the same way.
      REPAIR = "missing_files groups the members of each file that cannot be read: a renamed file usually takes " \
               "one new path for all of them. git_detected_rename, when given, is git's match for that path, to " \
               "#{RENAME_MATCH}".freeze #: String
      # broken holds each broken member's entry: its "id", any "principle", and its refusal's "code" and "path".
      #: (Array[Hash[String, untyped]], ?principle: String?, ?history: ProjectHistory?) -> void
      def initialize(broken, principle: nil, history: nil)
        @broken = broken
        @principle = principle
        @history = history
        freeze
      end

      # The broken members, each whose file is missing without a repair of its own, since the refusal's repair says
      # once how to repair the members missing_files groups.
      #: () -> Array[Hash[String, untyped]]
      def members = @broken.map { |entry| missing?(entry) ? entry.except("repair") : entry }

      # The broken_members refusal for these members, saying how to repair each. note comes before what
      # missing_files says, and rerun names what to run once they are repaired.
      # rerun is the command to run once the members are repaired, or nil when it is the one the agent ran.
      #: (String, ?rerun: String?, ?note: String) -> Error
      def refusal(message, rerun: nil, note: "")
        files = to_a
        Error.new("broken_members", message,
                  "For each member listed, say whether it moved or is gone, and run the matching command in its " \
                  "repair_with: the move-member, with its NEW_PATH, HEADING, NEW_OPENING_TEXT, NEW_ENDING_TEXT or " \
                  "QUERY filled in, if it moved, or the remove-member if it is gone. #{note}#{REPAIR}" \
                  "#{waiting(files)}#{rerun ? "\nThen run it again: #{rerun}" : " Then run the command again."}")
             .including(**({ "principle" => @principle } if @principle), "members" => members, "missing_files" => files)
      end

      # The broken_members refusal of the principle's map, naming each of these members.
      #: () -> Error
      def refusal_of_map
        ids = @broken.map { |member| member.fetch("id") }.join(", ")
        refusal("#{@broken.length} of #{@principle}'s members cannot be found or read: #{ids}")
      end

      # Each missing path, in the order first named, with the members that name it.
      #: () -> Array[Hash[String, untyped]]
      def to_a
        missing = @broken.select { |entry| missing?(entry) }.group_by { |entry| entry.fetch("path") }
        branches = brought_in(missing.keys)
        missing.map { |path, entries| file(path, entries, branches[path]) }
      end

      private

      # The missing path, with the entries of the members that name it, what git says of it, and on_branches, the
      # local branches that bring it in, when any does.
      #: (String, Array[Hash[String, untyped]], Array[String]?) -> Hash[String, untyped]
      def file(path, entries, branches)
        waiting_on = branches ? { "on_branches" => branches } : {}
        { "path" => path, "members" => entries.map { |entry| named(entry) } }.merge(renamed(path), waiting_on)
      end

      # The local branches that bring in each of paths, asked of git once, and only when a file is missing.
      #: (Array[String]) -> Hash[String, Array[String]]
      def brought_in(paths) = (@history&.branches_bringing_in(paths) unless paths.empty?) || {}

      # What the repair says of each of files a local branch brings in: that its members may wait for that branch to
      # merge, kept as they are, which is the agent's to judge.
      #: (Array[Hash[String, untyped]]) -> String
      def waiting(files)
        files.filter_map do |file|
          branches = file["on_branches"] or next
          named = ProseList.new(branches, conjunction: "or").to_s
          " #{file.fetch("path")} is on local branch #{named}, whose commits not on HEAD bring it in: if its " \
            "members wait on that branch, keep them as they are, running neither command, until #{named} merges."
        end.join
      end

      #: (Hash[String, untyped]) -> bool
      def missing?(entry)
        entry["code"] == "unreadable_file" && !entry["path"].nil?
      end

      # git_detected_rename for path, when git detects one.
      #: (String) -> Hash[String, untyped]
      def renamed(path)
        rename = @history&.rename_of(path)
        rename ? { "git_detected_rename" => rename } : {}
      end

      #: (Hash[String, untyped]) -> Hash[String, String]
      def named(entry)
        { "principle" => entry["principle"] || @principle, "id" => entry["id"] }.compact
      end
    end
  end
end

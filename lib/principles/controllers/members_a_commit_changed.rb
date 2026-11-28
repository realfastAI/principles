# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/plugin_reference"
require_relative "../views/members_a_commit_changed"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # list-member-problems --commits-after COMMIT --hook-event EVENT, which the plugin's after-commit hook runs once a
    # Bash call moved HEAD: the members the commits after COMMIT changed, as the hook's JSON, or nothing. It
    # exits 0 whatever it finds, since the host shows the user an error for any other status, and reports a refusal
    # only when those commits could have caused it, so a broken setup does not repeat at every commit (review R8).
    class MembersACommitChanged < Command
      # report gives list-member-problems' result for every map, as MemberProblemsReport checks it, or raises its
      # refusal.
      #: (Models::Project, tool: RunningTool, report: ^() -> Hash[String, untyped]) -> void
      def initialize(project, tool:, report:)
        super(project, tool: tool)
        @report = report
      end

      # The hook's output for the commits after `after`, run for event.
      #: (after: String, event: String) -> Views::Lines
      def printed(after:, event:)
        members = @report.call.fetch("members")
        changed = @history.commits_brought_in(after).changed_by(members)
        return Views::MembersACommitChanged::NOTHING if changed.empty?

        changed_lines(event, changed, others: still_listed(members - changed))
      rescue Error => e
        return Views::MembersACommitChanged::NOTHING unless @history.touched_since?(after, @principles.readable_paths)

        view.refused(event, e.payload.fetch("code"))
      end

      private

      # The hook's output naming changed, the members the commits changed, beside others still listed, those in a
      # plugin apart, since no commit changes them, with the wait of each of their principles whose record a later copy
      # wrote, which says why their audits wait.
      #: (String, Array[Hash[String, untyped]], others: Views::MembersACommitChanged::StillListed) -> Views::Lines
      def changed_lines(event, changed, others:)
        waits = changed.map { it.fetch("principle") }.uniq.filter_map { waiting_on_an_upgrade(it) }
        view.changed(event, changed, others:, waits:)
      end

      # The other members still listed, counted apart when a plugin holds them, which no commit changes.
      #: (Array[Hash[String, untyped]]) -> Views::MembersACommitChanged::StillListed
      def still_listed(others)
        in_plugins, from_commits = others.partition { Models::PluginReference.in(it.fetch("id")) }
        Views::MembersACommitChanged::StillListed.new(from_commits.size, in_plugins.size)
      end

      #: () -> Views::MembersACommitChanged
      def view = Views::MembersACommitChanged.new(invocation)
    end
  end
end

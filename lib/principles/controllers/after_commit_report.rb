# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "member_problems_report"
require_relative "../models/after_commit_input"
require_relative "../models/head_moves"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # report-after-commit, which a hook runs after each shell call: for the first repository the call committed in,
    # in the order Models::HeadMoves names them, whose commits changed a mapped member, the hook's JSON naming them,
    # as list-member-problems --commits-after prints it; or nothing. It exits 0 whatever it finds.
    class AfterCommitReport < Command
      # The project at a repository's root on this machine.
      PROJECT_AT = ->(root) { Models::Project.at(root) } #: ^(String) -> Models::Project

      # git_at gives what git says of a directory, as Models::HeadMoves asks it, and project_at the project at a
      # repository's root.
      #: (Models::Project, tool: RunningTool, ?git_at: ^(String) -> untyped,
      #|  ?project_at: ^(String) -> Models::Project) -> void
      def initialize(project, tool:, git_at: Models::HeadMoves::GIT_AT, project_at: PROJECT_AT)
        super(project, tool:)
        @git_at = git_at
        @project_at = project_at
      end

      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          unknown(command) unless command == "report-after-commit"

          input = Models::AfterCommitInput.read(options["stdin"].to_s, ENV.to_h, clock: Time.now.to_i, home: Dir.home,
                                                                                 pwd: Dir.pwd)
          event = input.event
          event ? reported(event, Models::HeadMoves.new(input, @git_at).to_a) : Views::MembersACommitChanged::NOTHING
        end
      end

      private

      # The first output naming a changed member, run for event on each move in turn.
      #: (String, Array[Models::HeadMoves::Move]) -> Views::Lines
      def reported(event, moves)
        moves.each do |move|
          lines = MemberProblemsReport.new(@project_at.call(move.root), tool: @tool)
                                      .call("list-member-problems", nil,
                                            { "hook_event" => event, "commits_after" => move.before })
          return lines unless lines.stdout.empty?
        end
        Views::MembersACommitChanged::NOTHING
      end
    end
  end
end

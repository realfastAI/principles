# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "members_a_commit_changed"
require_relative "../models/member_problems"
require_relative "../models/problem_report"
require_relative "../views/record_waiting_on_an_upgrade"
require_relative "../views/problem_result"
require_relative "../views/problem_lines"
require_relative "../views/first_audit_line"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # list-member-problems: each member of one map or every map checked against its baseline, printed as JSON, as
    # --short's lines, or for the after-commit hook through MembersACommitChanged.
    class MemberProblemsReport < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, id, options)
        naming_the_executable do
          command == "list-member-problems" ? printed(id, options) : unknown(command)
        end
      end

      # What report-at-session-start prints of every map's members, a line each, refused as list-member-problems
      # refuses: the lines --short --session-start SOURCE prints on stdout, then, in git, what gives each principle's
      # members with no baseline one, then each principle whose audits wait on an upgrade, whose members are not
      # counted. Outside git only an audit gives a baseline, so that line would repeat at every session.
      #: (String) -> Array[String]
      def session_start_lines(source)
        printing = invocation.without_project
        problems, (report,) = checked(nil, printing)
        lines = Views::ProblemLines.new(printing)
                                   .session_start_lines(changed: problems.assessed_changes, skill: skill?)
        lines + not_checked_lines(problems, report, printing, source)
      end

      private

      # The session-start lines on members this check cannot judge yet, after those counting the changed ones: what
      # gives members with no baseline one, then each principle whose audits wait on an upgrade, then, worded for the
      # session's source, the line asking for one subagent to run a first full audit while any principle awaits one.
      #: (Models::ProblemReport, Hash[String, untyped], Views::Invocation, String) -> Array[String]
      def not_checked_lines(problems, report, printing, source)
        no_baseline_lines(problems, report, printing) + waiting(nil).map(&:to_s) +
          Views::FirstAuditLine.new(printing).lines(problems.awaiting_first_audit.length, source)
      end

      # Whether this session has the principles skill, which only the plugin installs, for the lines naming where
      # to start.
      #: () -> bool
      def skill? = @tool.runs_from.principles_skill_in_this_session?

      # list-member-problems' JSON result, or with --short its lines for a trigger, or with --hook-event the
      # after-commit hook's JSON, which MembersACommitChanged prints.
      #: (String?, Hash[String, untyped]) -> untyped
      def printed(id, options)
        if (event = options["hook_event"])
          return handed(MembersACommitChanged, report: -> { checked_report(id) })
                 .printed(after: options.fetch("commits_after"), event: event)
        end

        return checked_report(id).merge("wrote" => []) unless options["short"]

        short(id, session_start: options["session_start"], named: options.key?("project"))
      end

      # list-member-problems --short's lines for map id, or every map, and the exit status they end with; with
      # --session-start, a count and command per principle in place of the rows.
      # session_start is the source --session-start names, or nil without it. named says whether the run was given
      # --project, which its commands then name; else its stderr names the project once and they leave it
      # out.
      #: (String?, session_start: String?, named: bool) -> Views::Lines
      def short(id, session_start:, named:)
        printing = named ? invocation : invocation.without_project
        problems, (report, names_a_command) = checked(id, printing)
        view = Views::ProblemLines.new(printing)
        lines = view.short(report, nothing_changed: Views::ProblemResult::NOTHING_CHANGED,
                                   assessed_change: problems.assessed_change?,
                                   never_assessed: problems.never_assessed, names_a_command:)
        return lines unless session_start

        view.at_session_start(lines, changed: problems.assessed_changes, skill: skill?)
      end

      # list-member-problems' JSON result for map id, or every map, without the files it wrote.
      #: (String?) -> Hash[String, untyped]
      def checked_report(id) = checked(id).last.first

      # The problems of map id, or every map, and list-member-problems' JSON result for them, with whether its
      # next_action names a command, naming each principle whose record a later copy wrote as waiting on an upgrade,
      # its members compared read-only. printing is the invocation its commands name.
      #: (String?, ?Views::Invocation) -> [Models::ProblemReport, [Hash[String, untyped], bool]]
      def checked(id, printing = invocation)
        waiting = waiting(id)
        problems = Models::ProblemReport.for(@project, id)
        [problems, member_problems(problems, waiting, printing)]
      end

      # Each principle, map id's or every map's, whose record a later copy wrote, so its audits wait on an upgrade.
      #: (String?) -> Array[Views::RecordWaitingOnAnUpgrade]
      def waiting(id) = (id ? [id] : @principles.ids).filter_map { waiting_on_an_upgrade(it) }

      # In git, what gives each principle's members with no baseline one, from problems and report, its result; none
      # outside git.
      #: (Models::ProblemReport, Hash[String, untyped], Views::Invocation) -> Array[String]
      def no_baseline_lines(problems, report, printing)
        return [] unless @history.inside_git?

        Views::ProblemResult.new(printing).no_baseline_actions(report, problems.files_to_commit(@principles))
                            .map(&:to_s)
      end

      # The result for problems, every member of map id or of every map that is broken or whose own text changed,
      # and each principle waiting on an upgrade.
      #: (Models::ProblemReport, Array[Views::RecordWaitingOnAnUpgrade], Views::Invocation)
      #|  -> [Hash[String, untyped], bool]
      def member_problems(problems, waiting, printing)
        report = problems.checked do |map_id, member, baseline, now, mapping|
          @project.principle_history(map_id, mapping: mapping).member_history(member, baseline: baseline, now: now)
        end
        Views::ProblemResult.new(printing)
                            .checked_naming_commands(report, not_read: @project.unread_older_files,
                                                             no_baseline_files: problems.files_to_commit(@principles),
                                                             acknowledgeable: problems.acknowledgeable_together(
                                                               except: waiting.map(&:principle)
                                                             ), waiting:)
      end
    end
  end
end

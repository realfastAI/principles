# typed: strict
# frozen_string_literal: true

require_relative "member_row"
require_relative "visible_text"
require_relative "invocation"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What a command prints as lines rather than JSON, and the exit status it ends with.
    Lines = Struct.new(:stdout, :stderr, :status, keyword_init: true)

    # list-member-problems --short, for a commit hook or heartbeat that acts on an exit status and short lines
    # alone: one tab-separated line per changed member on stdout, then one per principle counting its members
    # no audit has assessed, exit 3 when there is any line to act on, and on stderr what to do next and
    # anything an empty stdout would hide.
    class ProblemLines
      # The exit status that says a member's own text changed since an audit or acknowledgement assessed it, or that
      # no audit has assessed a member; 1 and 2 already mean refused and usage error.
      CHANGED = 3

      NO_MAPS = "No principle is mapped in this project, so there is nothing to check."

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # report is list-member-problems' JSON result: its "members", "counts" and "next_action".
      # assessed_change says whether a member an audit assessed changed, and never_assessed counts, by principle,
      # the members no audit has assessed; the model decides both, so the status follows from them alone.
      # names_a_command says whether next_action names one, as ProblemResult says.
      #: (Hash[String, untyped], nothing_changed: String, assessed_change: bool,
      #|  never_assessed: Hash[String, Integer], names_a_command: bool) -> Lines
      def short(report, nothing_changed:, assessed_change:, never_assessed:, names_a_command:)
        rows = report.fetch("members").map { MemberRow.new(it).short } +
               never_assessed.map { |id, count| counted(id, count) }
        Lines.new(stdout: rows.map { "#{it}\n" }.join,
                  stderr: notes(report, nothing_changed, names_a_command).map { |note| "#{note}\n" }.join,
                  status: assessed_change || !never_assessed.empty? ? CHANGED : 0)
      end

      # short's lines for a session-start hook: on stdout, first the context universal, unless source is
      # resume, whose conversation holds it already, then one line for each principle with a changed member an
      # audit or acknowledgement assessed, counting them, with the command that lists them, from changed, in place of
      # the rows and never-assessed counts, which an always-loaded carrier cannot afford, then where to start, as
      # session_start_lines says; stderr and the status kept. Its command leaves
      # out --project, as the hook's own commands do, since a session runs in its project.
      #: (Lines, changed: Hash[String, Integer], source: String, skill: bool) -> Lines
      def at_session_start(short, changed:, source:, skill:)
        stdout = session_start_lines(changed:, source:, skill:)
        Lines.new(stdout: stdout.map { "#{it}\n" }.join, stderr: short.stderr, status: short.status)
      end

      # at_session_start's stdout, a line each: the context universal, but on resume, then each principle's count
      # of changed audited members with the command that lists them, then, when any is, where to start: the principles
      # skill when skill says this session has it, as the plugin installs it, else those commands.
      #: (changed: Hash[String, Integer], source: String, skill: bool) -> Array[String]
      def session_start_lines(changed:, source:, skill:)
        counts = changed.map { |id, count| changed_line(id, count) }
        [*(Prompts.text("start-a-session/every-loaded-line-costs-every-session") unless source == "resume"),
         *counts, *(where_to_start(skill) unless counts.empty?)]
      end

      private

      # Where the agent starts with the changed members the count lines name: the principles skill, or without it the
      # commands those lines print.
      #: (bool) -> String
      def where_to_start(skill)
        return Prompts.text("start-a-session/start-with-the-principles-skill") if skill

        Prompts.text("start-a-session/run-each-command-above")
      end

      # The session-start line counting principle id's changed audited members, with the command that lists them.
      #: (String, Integer) -> String
      def changed_line(id, count)
        "#{count} audited member#{"s" unless count == 1} of #{VisibleText.new(id)} changed: " \
          "#{@invocation.without_project.in_project("list-member-problems", id, options: ["--short"])}"
      end

      # The line counting principle id's members no audit has assessed, which a reader tells from a member's row by
      # its two fields.
      #: (String, Integer) -> String
      def counted(id, count) = "#{VisibleText.new(id)}\t#{count} never assessed"

      # What the agent does next, and what an empty stdout would otherwise hide: no maps, or, in next_action,
      # each principle's members with no baseline to compare with and what gives them one, and each
      # principle waiting on an upgrade, whose members are not counted, so they leave counts empty.
      #: (Hash[String, untyped], String, bool) -> Array[String]
      def notes(report, nothing_changed, names_a_command)
        no_maps = report.fetch("counts").empty? && !report.key?("empty_maps") &&
                  !report.key?("records_waiting_on_an_upgrade")
        action = report.fetch("next_action")
        [(NO_MAPS if no_maps), (project_line if names_a_command),
         (action unless action == nothing_changed)].compact
      end

      # The project once, before the first command stderr prints, where they run since they leave out --project,
      # and how to see the details rows leave out, such as each commit's subject; only the latter when each
      # command names --project already.
      #: () -> String
      def project_line
        return "Details: drop --short." if @invocation.named?

        "In #{@invocation.project_word} (details: drop --short):"
      end
    end
  end
end

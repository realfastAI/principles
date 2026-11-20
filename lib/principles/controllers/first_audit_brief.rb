# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/first_full_audit"
require_relative "../models/problem_report"
require_relative "../views/first_audit_brief"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # show-first-audit-brief: the instructions for one background subagent to run a principle's first full audit,
    # so the session that starts it spends a few hundred bytes of its context on the audit rather than tens of
    # kilobytes. It writes nothing.
    class FirstAuditBrief < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, id, _options)
        naming_the_executable do
          unknown(command) unless command == "show-first-audit-brief"

          id ? brief(id) : view.awaiting(Models::ProblemReport.for(@project, nil).awaiting_first_audit)
        end
      end

      private

      # The brief for principle id, refused once a full audit of it has completed.
      #: (String) -> Hash[String, untyped]
      def brief(id)
        @principles.find(id)
        Models::FirstFullAudit.new(id, @audit_records.find(id)).refuse_once_completed
        view.result(id)
      end

      #: () -> Views::FirstAuditBrief
      def view = Views::FirstAuditBrief.new(invocation)
    end
  end
end

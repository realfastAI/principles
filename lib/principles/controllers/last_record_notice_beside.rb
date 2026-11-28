# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../views/last_record_notice"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The notice a full audit's request prints when the last audit's record of its principle was left uncommitted,
    # which FullAuditRequest hands over: a completed one to commit, or an open one, which its correction completes,
    # never to commit; and, when the open record keeps its correction, how to resume it.
    class LastRecordNoticeBeside < Command
      # principle_id names the principle audited; base is the commit its audit is based on, nil outside git.
      #: (Models::Project, tool: RunningTool, principle_id: String, base: String?) -> void
      def initialize(project, tool:, principle_id:, base:)
        super(project, tool: tool)
        @id = principle_id
        @base = base
      end

      # output, with the notice when there is one, committed or not, in git or outside.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def beside(output)
        record = @audit_records.find(@id)
        notices = Views::LastRecordNotice.new(invocation)
        resume = (notices.resume(@id) if record&.correction)
        notice = [uncommitted_record_notice(record, notices), resume].compact.join(" ")
        notice.empty? ? output : output.merge("notice" => notice)
      end

      private

      # What notices says of record when, in git, its file differs from the last commit, or nil when it does not.
      #: (Models::AuditRecord?, Views::LastRecordNotice) -> String?
      def uncommitted_record_notice(record, notices)
        return unless @base && uncommitted_record?

        file = @audit_records.file(@id)
        record&.open? ? notices.open(file) : notices.uncommitted(file)
      end

      # Whether the last audit's record exists but differs from the last commit, so it may be left behind.
      #: () -> bool
      def uncommitted_record?
        @audit_records.exist?(@id) && @history.uncommitted([@audit_records.file(@id)]).any?
      end
    end
  end
end

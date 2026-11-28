# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/findings_left_open"
require_relative "../models/finding_write_ups"
require_relative "../views/audit_findings"
require_relative "../views/findings_result"
require_relative "../views/open_findings_line"
require_relative "acknowledgement"
require_relative "acknowledgements"
require_relative "full_audit_request"
require_relative "open_finding_decisions"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # Starting and showing an audit: start-audit hands the agent the assessment request, which FullAuditRequest
    # builds for a full audit, and show-audit prints the committed record.
    class Audit < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, id, options)
        return started_audit(required_id(id), options) if command == "start-audit"

        naming_the_executable do
          case command
          when "show-audit" then shown_audit(required_id(id), findings: options["findings"])
          when "list-open-findings" then listed_open_findings(id, options)
          else unknown(command)
          end
        end
      end

      # The line report-at-session-start ends with while any finding is open, worded for the session's start, source,
      # with list-open-findings --short's words, its command leaving out --project, since a session runs in its
      # project; none while none is open.
      #: (String) -> Array[String]
      def session_start_open_findings(source)
        records = open_records(nil)
        waiting = Models::FindingsLeftOpen.of(records).waiting_at(Time.now.utc)
        not_found = Models::FindingWriteUps.of(@project, records).not_found
        Views::OpenFindingsLine.new(invocation.without_project)
                               .lines(waiting, not_found, source:)
      end

      private

      # The audit start-audit's options ask for: a one-member audit with --member, a decision on the open
      # findings with --open-findings, else a full audit, refusing --write-ups; an audit's answer alone with
      # --as template.
      #: (String, Hash[String, untyped]) -> Hash[String, untyped]
      def started_audit(id, options)
        refuse_write_ups(id) if options["write_ups"]
        naming_the_executable { @audit_records.refuse_newer(id, version: @tool.version) }
        ids = [id, *options.fetch("other_ids", [])]
        return acknowledge(ids, options.fetch("member"), to_fill: options["as"] == "template") if options["member"]
        return handed(OpenFindingDecisions).decide(id, to_fill: options["as"] == "template") if options["open_findings"]

        full_audit(id, options)
      end

      # Refuses --write-ups, which --open-findings replaced for one release, printing the request for principle id
      # that replaces it (013 R12).
      #: (String) -> bot
      def refuse_write_ups(id)
        raise Error.new("replaced_option",
                        "--write-ups is replaced by --open-findings, which also changes a finding's wait and action",
                        "Run instead: #{invocation.in_project("start-audit", id, usage: "--open-findings")}")
      end

      # A full audit's request, or with --as template its answer alone, or with --instruction one instruction field
      # of it, or with --part one other part of it, or one member's slot of the answer beside --as template.
      #: (String, Hash[String, untyped]) -> Hash[String, untyped]
      def full_audit(id, options)
        naming_the_executable do
          full = handed(FullAuditRequest, principle_id: id)
          next full.instruction(options["instruction"]) if options["instruction"]
          next full_part(full, options) if options["part"]

          options["as"] ? full.to_fill : full.printed
        end
      end

      # The part of the request --part names, or beside --as template the member's slot of the answer it names.
      #: (FullAuditRequest, Hash[String, untyped]) -> Hash[String, untyped]
      def full_part(full, options)
        parts = options.fetch("part")
        options["as"] ? full.slot_to_fill(parts) : full.part(parts)
      end

      # id's committed record. With none, an id no map has is refused as show-principle refuses it, since
      # starting its audit would be refused too; a record kept after its map was removed still shows. One a
      # later copy wrote says its audits wait on an upgrade. With --findings, only its findings and those of the
      # last completed audit it keeps.
      #: (String, findings: bool?) -> Hash[String, untyped]
      def shown_audit(id, findings:)
        @principles.find(id) unless @audit_records.exist?(id)
        record = @audit_records.fetch(id)
        (findings ? findings_of(record) : record.shown).merge(waiting_beside(id), "wrote" => [])
      end

      # The findings of record, and of the last completed record it keeps while open.
      #: (Models::AuditRecord) -> Hash[String, untyped]
      def findings_of(record)
        kept = record.open? ? record.last_completed&.shown : nil
        Views::AuditFindings.new(record.shown, kept).to_h
      end

      # A one-member audit of the member --member names, or of several members in one request, or of the
      # members several principles map, or its answer alone to fill.
      #: (Array[String], Array[String], to_fill: bool) -> Hash[String, untyped]
      def acknowledge(ids, member_ids, to_fill:)
        id = ids.fetch(0)
        return handed(Acknowledgements).across(ids, member_ids, to_fill:) if ids.size > 1
        return handed(Acknowledgements).several(id, member_ids, to_fill:) if member_ids.size > 1

        acknowledgement = handed(Acknowledgement)
        member_id = member_ids.first.to_s

        to_fill ? acknowledgement.to_fill(id, member_id) : acknowledgement.start(id, member_id)
      end

      # The open findings in the form the options ask for: the session-start hook's one line with --short, a line each
      # with --lines, or the full list.
      #: (String?, Hash[String, untyped]) -> untyped
      def listed_open_findings(id, options)
        return open_findings_line(id, options) if options["short"]
        return open_findings_lines(id) if options["lines"]

        open_findings(id)
      end

      # Each open finding on a line, with whom it waits on and how long it has been open until now.
      #: (String?) -> Views::Lines
      def open_findings_lines(id)
        now = Time.now.utc
        Views::FindingsResult.new(invocation).lines(open_records(id).flat_map(&:left_open).map { it.waited_at(now) })
      end

      # The findings the last completed audit of map id, or of every map, deferred or accepted. Across
      # every map, it names each principle whose record a later copy wrote, so a list left without one that cannot be
      # read does not look whole.
      #: (String?) -> Hash[String, untyped]
      def open_findings(id)
        listed = Models::FindingWriteUps.of(@project, open_records(id)).listed
        result = Views::FindingsResult.new(invocation).open(listed)
        waiting = id ? [] : @principles.ids.filter_map { waiting_on_an_upgrade(it) }
        result = result.merge("records_waiting_on_an_upgrade" => waiting.map(&:to_h)) unless waiting.empty?
        result.merge("wrote" => [])
      end

      # The one line saying how many findings are open and how long the oldest has waited until now, and which
      # write-ups can no longer be found, or nothing when none is open, for a session-start hook,
      # worded for the session's start, startup unless --session-start names another.
      #: (String?, Hash[String, untyped]) -> Views::Lines
      def open_findings_line(id, options)
        records = open_records(id)
        waiting = Models::FindingsLeftOpen.of(records).waiting_at(Time.now.utc)
        Views::OpenFindingsLine.new(invocation).short(waiting, Models::FindingWriteUps.of(@project, records).not_found,
                                                      source: options["session_start"] || "startup")
      end

      # The records whose open findings list-open-findings reads: id's, refused when a later copy wrote it in a
      # form this copy cannot read, since an empty list would say it has none; or every principle's this copy can
      # read, so one such record does not refuse the rest.
      #: (String?) -> Array[Models::AuditRecord]
      def open_records(id)
        ids = @principles.ids_of(id)
        id ? @audit_records.of(ids) : @audit_records.readable_of(ids)
      end
    end
  end
end

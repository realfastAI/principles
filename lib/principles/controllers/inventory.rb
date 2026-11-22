# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/member_state"
require_relative "../models/meta_principle"
require_relative "../views/principle_read_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The reads that show what a project has mapped: its principles, and each member and how fresh it is against the
    # last audit. None changes anything on disk. Survey runs the survey of candidate files.
    class Inventory < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, id, options)
        naming_the_executable do
          case command
          when "list-principles" then listing(open_findings: options["open_findings"]).merge("wrote" => [])
          when "show-principle" then members(required_id(id)).merge("wrote" => [])
          else unknown(command)
          end
        end
      end

      # Each principle id names as list-principles lists it: its description and its members by freshness, or the
      # refusal that kept its map from being read.
      #: (Array[String]) -> Array[Hash[String, untyped]]
      def rows(ids) = ids.map { entry(it) }

      private

      #: (String) -> untyped
      def members(id)
        principle = @principles.find(id)
        audit = @audit_records.find(id)
        hooks = @project.hook_commands
        members = shown_members(principle, audit, hooks)
        shown = read_result.shown(printed_principle(principle, members: members),
                                  repairs: repairs(principle, members), hook_settings_not_read: hooks.not_read,
                                  loaded_files: @project.loaded_files(principle.members, hooks).to_h)
        return shown unless audit

        shown.merge("last_audit" => audit.last_audit(map_version: principle.version))
      end

      # Each member as show-principle prints it, with its loads read once for the whole map, from hooks.
      #: (Models::Principle, Models::AuditRecord?, Models::HookCommands) -> Array[Hash[String, untyped]]
      def shown_members(principle, audit, hooks)
        loads = member_loads(principle, hooks)
        principle.members_shown.map do |member|
          shown_member(member, audit, loads.fetch(member.fetch("id"))).merge(shared(member, map: principle))
        end
      end

      # What show-principle prints of one member: where it is now, its freshness and when its file loads.
      # The span sits beside the id too, as in add-member's and move-member's results (alpha friction).
      #: (Hash[String, untyped], Models::AuditRecord?, Models::MemberLoads) -> Hash[String, untyped]
      def shown_member(member, audit, loads)
        now = fresh(member, audit&.members&.hashes || Models::RecordedHashes::NONE)
        member.merge(now.fetch("snapshot", {}).slice("first_line", "last_line"), now,
                     "loads" => loads.to_h)
      end

      # The moves that may repair each shown member whose reference is broken, so an audit would refuse it, by id in the
      # map's order.
      #: (Models::Principle, Array[Hash[String, untyped]]) -> Hash[String, Array[Views::MemberRepairs::Move]]
      def repairs(principle, members)
        broken = broken_member_repairs
        members.select { |member| Models::MemberState.new(member.fetch("id"), member.fetch("freshness")).broken? }
               .to_h do |member|
          id = member.fetch("id")
          error = member.fetch("error", {})
          [id, broken.moves(principle.member(id), code: error["code"], tracked_as: error["tracked_as"])]
        end
      end

      # The members sharing a line with this one, in its map and in others, as add-member names them, so a member
      # whose lines others hold too does not look as if its member_bytes were its alone. A member this tool
      # cannot find now shares nothing it can name.
      #: (Hash[String, untyped], map: Models::Principle) -> Hash[String, untyped]
      def shared(member, map:)
        lines_shared(Models::Member.new(member), map).to_h
      rescue Error
        {}
      end

      # Where the member is now and whether it changed since the record holding hashes assessed it.
      #: (Hash[String, untyped], Models::RecordedHashes) -> Hash[String, untyped]
      def fresh(member, hashes)
        found = Models::Member.new(member)
        @project.freshness(found.locator) { |sha| hashes.freshness(found.key, sha) }
      end

      #: () -> Views::PrincipleReadResult
      def read_result
        Views::PrincipleReadResult.new(invocation)
      end

      # Its next_action offers an audit while one principle's audits do not wait on an upgrade; a map listed with its
      # refusal counts, since repairing it leaves it to audit. With open_findings, each row lists its open findings.
      #: (open_findings: bool?) -> untyped
      def listing(open_findings:)
        ids = @principles.ids
        waiting = ids.filter_map { waiting_on_an_upgrade(it) }
        listed = open_findings ? read_result.with_open_findings(rows(ids), open_by_principle(ids)) : rows(ids)
        read_result.listing(listed, waiting: waiting, one_to_audit: waiting.size < ids.size)
      end

      # Each principle's open findings, from every record this copy can read, as list-open-findings reads them,
      # aged until now, by principle id.
      #: (Array[String]) -> Hash[String, Array[Hash[String, untyped]]]
      def open_by_principle(ids)
        now = Time.now.utc
        @audit_records.readable_of(ids).flat_map(&:left_open).map { it.waited_at(now) }
                      .group_by { it.fetch("principle") }
      end

      # One map's row; a map this tool cannot read is listed with its refusal, so the others still show, and one
      # whose record a later copy wrote says its audits wait on an upgrade, as show-audit does.
      #: (String) -> Hash[String, untyped]
      def entry(id)
        map = @principles.find(id)
        row = map.description_with_id.merge("members_by_freshness" => members_by_freshness(map))
        row = row.merge(read_result.no_members(@principles.file(id))) if map.unstarted?
        row.merge(waiting_on_an_upgrade(id)&.marker || {})
      rescue Error => e
        { "id" => id, "refusal" => e.payload }
      end

      # How many of map's members are in each freshness state, against its principle's last audit, or the hashes a
      # record a later copy wrote holds, read-only, when this copy cannot read the rest of it.
      #: (Models::Principle) -> Hash[String, Integer]
      def members_by_freshness(map)
        hashes = @audit_records.hashes_to_compare(map.id)
        map.members_shown.map { |member| fresh(member, hashes).fetch("freshness") }.tally.sort.to_h
      end
    end
  end
end

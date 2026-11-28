# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../views/principle_read_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # list-principles: each mapped principle with its members counted by freshness against its last audit, or the
    # refusal that kept its map from being read. It changes nothing on disk. Inventory shows one principle.
    class PrincipleListing < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          case command
          when "list-principles" then listed(options)
          else unknown(command)
          end
        end
      end

      # Each principle id names as list-principles lists it: its description and its members by freshness, or the
      # refusal that kept its map from being read.
      #: (Array[String]) -> Array[Hash[String, untyped]]
      def rows(ids) = ids.map { entry(it) }

      private

      #: () -> Views::PrincipleReadResult
      def read_result
        Views::PrincipleReadResult.new(invocation)
      end

      # list-principles as options ask: each id on a line with --lines, else the rows as JSON.
      #: (Hash[String, untyped]) -> untyped
      def listed(options)
        return read_result.ids(@principles.ids) if options["lines"]

        listing(open_findings: options["open_findings"]).merge("wrote" => [])
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

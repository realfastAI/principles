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
    # show-principle: each member of one principle and how fresh it is against the last audit. It changes nothing on
    # disk. PrincipleListing lists every principle, and Survey runs the survey of candidate files.
    class Inventory < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, id, options)
        naming_the_executable do
          case command
          when "show-principle" then shown(required_id(id), options).merge("wrote" => [])
          else unknown(command)
          end
        end
      end

      private

      # The principle id names as show-principle prints it, or only the member --member names, refused when its map
      # lacks it.
      #: (String, Hash[String, untyped]) -> untyped
      def shown(id, options)
        member_id = options["member"]&.first
        return members(id, loads: options["loads"]) unless member_id

        one_member(@principles.find(id), member_id)
      end

      # The member of principle with member_id, where it is now, how fresh against the last audit, and the last
      # judgements the last completed audit's record keeps of it: its assessment and the last acknowledgement since.
      #: (Models::Principle, String) -> Hash[String, untyped]
      def one_member(principle, member_id)
        member = principle.member(member_id)
        audit = @audit_records.find(principle.id)
        now = fresh(member, audit&.members&.hashes || Models::RecordedHashes::NONE)
        span = now.fetch("snapshot", {}).slice("first_line", "last_line")
        read_result.one_member(principle.id, { "id" => member_id, **member, **span, **now.except("snapshot") },
                               *judgements(audit, Models::Member.new(member).key))
      end

      # The assessment the last completed audit in audit kept for the member known by key, and the last
      # acknowledgement made of it since, each none when the record keeps none.
      #: (Models::AuditRecord?, String) -> [Hash[String, untyped]?, Hash[String, untyped]?]
      def judgements(audit, key)
        completed = audit&.last_completed or return [nil, nil]
        [completed.members.recorded(key)&.assessment, completed.members.acknowledgements_for(key).last]
      end

      # The principle id names as show-principle prints it, with when each member's file loads only when loads asks.
      #: (String, loads: bool?) -> untyped
      def members(id, loads:)
        principle = @principles.find(id)
        audit = @audit_records.find(id)
        shown = principle_shown(principle, audit, loads: loads)
        return shown unless audit

        shown.merge("last_audit" => audit.last_audit(map_version: principle.version))
      end

      # The principle with each member and its repairs, and with loads also when each member's file loads, the files
      # they load and the hook settings not read; without, its next_action names --loads.
      #: (Models::Principle, Models::AuditRecord?, loads: bool?) -> Hash[String, untyped]
      def principle_shown(principle, audit, loads:)
        hooks = @project.hook_commands
        members = shown_members(principle, audit, hooks)
        if loads
          return members_listed(principle, members, hook_settings_not_read: hooks.not_read,
                                                    loaded_files: @project.loaded_files(principle.members, hooks).to_h)
        end

        read_result.without_loads(members_listed(principle, members.map { it.except("loads") }), principle.id)
      end

      # The principle with members, their repairs and the plugin members no installed plugin gives, beside what
      # show-principle --loads adds: the hook settings not read and the files the members load.
      #: (Models::Principle, Array[Hash[String, untyped]], ?hook_settings_not_read: Array[Hash[String, String]],
      #|  ?loaded_files: Hash[String, untyped]) -> Hash[String, untyped]
      def members_listed(principle, members, hook_settings_not_read: [], loaded_files: {})
        unresolved = members.select { unresolved?(it) }.map { it.fetch("id") }
        read_result.shown(printed_principle(principle, members: members), repairs: repairs(principle, members),
                                                                          hook_settings_not_read:, loaded_files:,
                                                                          unresolved:)
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
                     "loads" => loads.to_h, **plugin_source(member, now))
      end

      # Where a plugin member found now comes from, at the version installed now, read-only; nothing for a project
      # file, or for a plugin member now says no installed plugin gives.
      #: (Hash[String, untyped], Hash[String, untyped]) -> Hash[String, untyped]
      def plugin_source(member, now)
        return {} if unresolved?(now)

        source = @project.installed_plugins.source_of(Models::Member.new(member))
        source ? { "source" => source } : {}
      end

      # Whether a member shown is a plugin member no installed plugin gives.
      #: (Hash[String, untyped]) -> bool
      def unresolved?(shown) = shown.fetch("freshness") == "plugin_unresolved"

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

      #: () -> Views::PrincipleReadResult
      def read_result
        Views::PrincipleReadResult.new(invocation)
      end
    end
  end
end

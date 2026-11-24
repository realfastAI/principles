# typed: strict
# frozen_string_literal: true

require_relative "findings_result"
require_relative "invocation"
require_relative "printed_principle"
require_relative "member_repairs"
require_relative "prompts"
require_relative "record_waiting_on_an_upgrade"
require_relative "../prose_list"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The JSON results of reading principles, show-principle and list-principles, with commands for the invocation
    # running now. They change with what a read reports, such as freshness and repairs; MapResult prints the writes.
    class PrincipleReadResult
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # show-principle: each member with where its text is now and its freshness, and each member repairs names, those
      # an audit would refuse, with its repair_with commands, from the moves repairs gives it.
      # hook_settings_not_read names each project settings file whose hooks this tool could not read.
      # loaded_files lists each file the members load once, with the total of those loading at session start.
      #: (PrintedPrinciple, repairs: Hash[String, Array[MemberRepairs::Move]],
      #|  ?hook_settings_not_read: Array[Hash[String, String]], ?loaded_files: Hash[String, untyped])
      #|  -> Hash[String, untyped]
      def shown(principle, repairs:, hook_settings_not_read: [], loaded_files: {})
        unread = hook_settings_not_read.empty? ? {} : { "hook_settings_not_read" => hook_settings_not_read }
        { "id" => principle.id, "map_file" => principle.file, **principle.declared,
          "members" => principle.members.map { |member| repaired(principle.id, member, repairs) },
          **loaded_files, **unread, "next_action" => shown_next_action(principle, repairs.keys) }
      end

      # list-principles: each entry is { "id", "description", "members_by_freshness" }. waiting is each principle whose
      # audits wait on an upgrade, which it names, with how to update said once, and an audit is offered only when one
      # is left to audit.
      #: (Array[Hash[String, untyped]], ?waiting: Array[RecordWaitingOnAnUpgrade], ?one_to_audit: bool)
      #|  -> Hash[String, untyped]
      def listing(entries, waiting: [], one_to_audit: true)
        { "principles" => entries, "next_action" => listed_next_action(entries, waiting, one_to_audit).join("\n") }
      end

      # list-principles --lines: each mapped principle's id on a line of its own, for a shell loop; nothing when none
      # is mapped.
      #: (Array[String]) -> Lines
      def ids(ids) = Lines.new(stdout: ids.map { "#{it}\n" }.join, stderr: "", status: 0)

      # Each of list-principles' entries with its principle's open findings, a line each, for --open-findings. open
      # maps each principle id to its findings' plain fields, as list-open-findings --lines takes them.
      #: (Array[Hash[String, untyped]], Hash[String, Array[Hash[String, untyped]]]) -> Array[Hash[String, untyped]]
      def with_open_findings(entries, open)
        findings = FindingsResult.new(@invocation)
        entries.map do |entry|
          entry.merge("open_findings" => open.fetch(entry.fetch("id"), []).map { findings.summary(it) })
        end
      end

      # list-principles' note on the meta-principle's map, kept in file, when it has no members, with the two ways on.
      #: (String) -> Hash[String, String]
      def no_members(file)
        setup = @invocation.in_project("show-meta-principle-passage")
        { "no_members" => "This map has no members, as a setup that wrote it before its first member, or removing " \
                          "its last member, leaves it. Either remove #{file} and commit the removal, or add its " \
                          "first member with the add-member this prints: #{setup}" }
      end

      private

      # What list-principles' next_action offers: mapping one when none is listed, else showing one,
      # auditing one when one is left to audit, and the principles whose audits wait on an upgrade.
      #: (Array[Hash[String, untyped]], Array[RecordWaitingOnAnUpgrade], bool) -> Array[String]
      def listed_next_action(entries, waiting, one_to_audit)
        return ["To map one, start with: #{@invocation.in_project("list-candidate-files")}"] if entries.empty?

        audit = "To audit it: #{@invocation.in_project("start-audit", usage: "ID")}" if one_to_audit
        waits = waited_on(waiting) unless waiting.empty?
        ["To see a principle's members: #{@invocation.in_project("show-principle", usage: "ID")}", audit,
         "To survey this project: #{@invocation.in_project("list-candidate-files")}",
         "To survey the principles a change carries: " \
         "#{@invocation.in_project("list-candidate-files", usage: "--commits-after REV")}", waits].compact
      end

      # The principles whose audits wait on an upgrade, and how to update, once for each way the records name.
      #: (Array[RecordWaitingOnAnUpgrade]) -> String
      def waited_on(waiting)
        ["The audits of #{ProseList.new(waiting.map(&:principle))} wait on an upgrade.", *waiting.map(&:update).uniq]
          .join(" ")
      end

      # member, with its repairs when repairs names it.
      #: (String, Hash[String, untyped], Hash[String, Array[MemberRepairs::Move]]) -> Hash[String, untyped]
      def repaired(id, member, repairs)
        MemberRepairs.new(@invocation).beside(id, member, repairs[member.fetch("id")])
      end

      # Repair each member in broken, the ids of those an audit would refuse; otherwise audit when one changed or was
      # never assessed.
      #: (PrintedPrinciple, Array[String]) -> String
      def shown_next_action(principle, broken)
        unless broken.empty?
          return "Repair each member that cannot be found or read before auditing, with one of the commands in " \
                 "its repair_with: #{broken.join(", ")}."
        end

        "Audit when a member is changed or unassessed: #{@invocation.in_project("start-audit", principle.id)}"
      end
    end
  end
end

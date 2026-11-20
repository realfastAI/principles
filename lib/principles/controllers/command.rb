# typed: strict
# frozen_string_literal: true

require "shellwords"
require_relative "../error"
require_relative "../models/answer_text"
require_relative "../models/audit"
require_relative "../models/carried_assessments"
require_relative "../models/member"
require_relative "../models/member_grounds"
require_relative "../models/member_repair_moves"
require_relative "../models/principle_history"
require_relative "../models/members_sharing_lines"
require_relative "../models/project"
require_relative "../models/record_format"
require_relative "../models/record_judged_against"
require_relative "../views/audit_result"
require_relative "../views/lines_shared_with_member"
require_relative "../views/map_result"
require_relative "../views/member_repairs"
require_relative "../views/record_waiting_on_an_upgrade"
require_relative "running_tool"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # What every command controller shares: the project and its models, the views that print, and the
    # running executable, which only a controller knows. Reads change nothing on disk, map writes touch only
    # the committed map, and audit writes only the committed audit record; lib/principles/CLAUDE.md owns the
    # naming rule that keeps the three apart.
    class Command
      # The command as the agent can run it from a checkout or an installed gem: this Ruby and this checkout's
      # executable, because this tool is not on the PATH there. The path is shell-quoted, since an install
      # directory may hold a space. An entry point that is on the PATH names itself instead.
      INVOCATION = "ruby #{Shellwords.escape(File.expand_path("../../../exe/principles", __dir__))}".freeze #: String

      # tool is this run of the tool: the executable every printed command names, and the version running.
      #: (Models::Project, tool: RunningTool) -> void
      def initialize(project, tool:)
        @project = project
        @tool = tool
        @principles = @project.principles #: Models::MappedPrinciples
        @audit_records = @project.audit_records #: Models::AuditRecords
        @history = @project.history #: Models::ProjectHistory
      end

      # Runs command; each controller runs its own group's commands and refuses the rest.
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, _options)
        naming_the_executable { unknown(command) }
      end

      private

      # The command's shared history view for principle_id's map.
      #: (String) -> Models::PrincipleHistory
      def principle_history(principle_id)
        @project.principle_history(principle_id)
      end

      # Saves the map, and nothing else, then prints the result the block builds from the map as written.
      #: (Models::Principle) { (Views::PrintedPrinciple) -> Hash[String, untyped] } -> untyped
      def write_map(map, &)
        wrote = @principles.save(map)
        yield(printed_principle(map)).merge("wrote" => [wrote])
      end

      # Runs the block, putting the running executable into any refusal a model raised, followed by this project,
      # so a repair runs on the same project from anywhere, as answer_with does. rerun, when given, prints the
      # command running now with another member id, which a refusal naming a near miss leads its repair with.
      #: [T] (?rerun: (^(String) -> String)?) { () -> T } -> T
      def naming_the_executable(rerun: nil, &)
        yield
      rescue Error => e
        refusal = (rerun ? e.rerun_with_near_miss(&rerun) : e).printing_commands do |command|
          invocation.listed_in_project(command.command, command.values, options: command.options, usage: command.usage)
        end
        raise with_member_repairs(refusal).naming(invocation.prefix)
      end

      # A broken_members refusal, with each member's own repair commands beside it as repair_with, since a
      # model's repair can only name placeholders. Any other refusal is returned as it is.
      #: (Error) -> Error
      def with_member_repairs(error)
        return error unless error.payload["code"] == "broken_members"

        repairs = Views::MemberRepairs.new(invocation)
        members = error.payload.fetch("members").map do |entry|
          repaired({ "principle" => error.payload["principle"] }.compact.merge(entry), repairs)
        end
        error.including("members" => members)
      end

      # entry with repair_with, when it names a member its map still lists.
      #: (Hash[String, untyped], Views::MemberRepairs) -> Hash[String, untyped]
      def repaired(entry, repairs)
        principle = entry["principle"] or return entry
        id = entry["id"] or return entry
        member = @principles.find(principle).member(id)
        moves = Models::MemberRepairMoves.new(member, code: entry["code"], tracked_as: entry["tracked_as"]).to_a
        entry.merge("repair_with" => repairs.commands(principle, id, moves))
      rescue Error
        entry
      end

      #: (String) -> bot
      def unknown(command)
        raise Error.new("unknown_command", "Unknown command #{command}",
                        "To see every command: #{@tool.executable} --help")
      end

      # The controller this one hands part of its command to, over the same project and naming the same executable.
      #: [C < Command] (Class[C], **untyped) -> C
      def handed(controller, **)
        controller.new(@project, tool: @tool, **)
      end

      # The executable and project that printed commands name, built for each run and never stored.
      #: () -> Views::Invocation
      def invocation
        @tool.invocation(@project.root)
      end

      # Principle id as waiting on an upgrade, when a later copy wrote its record.
      #: (String) -> Views::RecordWaitingOnAnUpgrade?
      def waiting_on_an_upgrade(id)
        format = @audit_records.newer_format(id) or return
        Views::RecordWaitingOnAnUpgrade.new(principle: id, format: format.number, first_release: format.first_release,
                                            newest: Models::RecordFormat::NEWEST, update: format.update_either_way)
      end

      # The line saying principle id's audits wait on an upgrade, as a field to print beside it, or none.
      #: (String) -> Hash[String, String]
      def waiting_beside(id) = waiting_on_an_upgrade(id)&.beside || {}

      #: () -> Views::AuditResult
      def audit_result
        Views::AuditResult.new(invocation)
      end

      #: () -> Views::MapResult
      def map_result
        Views::MapResult.new(invocation, in_git: @history.inside_git?)
      end

      #: (String?) -> String
      def required_id(id)
        unless id
          raise Error.new("missing_id", "An id is required",
                          "To see each command's examples: #{@tool.executable} --help")
        end

        id
      end

      #: (untyped, String) -> String
      def text(value, field) = Models::AnswerText.new(value).required(field)

      # The principle as the view prints it, with each member's id beside its locator.
      #: (Models::Principle, ?members: Array[Hash[String, untyped]]) -> Views::PrintedPrinciple
      def printed_principle(map, members: map.members_shown)
        Views::PrintedPrinciple.new(id: map.id, file: @principles.file(map.id), description: map.description,
                                    members: members, activation: map.activation)
      end

      # Each member's hash at base, or nil outside git.
      #: (String?, Models::Principle) -> Hash[String, String]?
      def committed(base, map) = base ? @history.hashes_at(base, map.members) : nil

      # When each of the map's members loads, by id, which a full audit's request lists against the activation and
      # show-principle prints, from the project's hooks as hooks read them.
      #: (Models::Principle, ?Models::HookCommands) -> Hash[String, Models::MemberLoads]
      def member_loads(map, hooks = @project.hook_commands) = @project.member_loads(map.members, hooks)

      # The members a full audit lists to check against its activation, each with the decision its last completed
      # audit, whose record is given or read now, accepted on the member's loading.
      #: (Models::Audit, ?Models::AuditRecord?) -> Models::LoadsToCheck
      def loads_to_check(audit, record = @audit_records.find(audit.id))
        audit.loads_to_check(member_loads(audit.map), record)
      end

      # The principle's audit record as it stands, as an assessment answer is judged against it: the members whose
      # loads it decides and the assessments it may carry forward, from one read of the record.
      #: (Models::Audit) -> Models::RecordJudgedAgainst
      def record_judged_against(audit)
        record = @audit_records.find(audit.id)
        Models::RecordJudgedAgainst.new(loads: loads_to_check(audit, record),
                                        carried: carried_assessments(audit, record), record: record)
      end

      # What each member's assessment was judged on beside its text: its map entry and when it loads.
      #: (Models::Audit) -> Models::MemberGrounds
      def grounds(audit) = audit.grounds(member_loads(audit.map))

      # Which members' last assessments a full audit carries forward, from its record, given or read now, and the
      # question it asks.
      #: (Models::Audit, ?Models::AuditRecord?) -> Models::CarriedAssessments
      def carried_assessments(audit, record = @audit_records.find(audit.id))
        audit.carried_assessments(record, grounds: grounds(audit), question: Views::AssessmentRequest.question)
      end

      # Where a member is in its file now, and the hash of what it says there.
      #: (Models::Locator) -> Hash[String, untyped]
      def snapshot(locator)
        @project.locate(locator)
      end

      # The members sharing a line with member where it is now, in map and in the other maps, as add-member and
      # show-principle print them.
      #: (Models::Member, Models::Principle) -> Views::LinesSharedWithMember
      def lines_shared(member, map)
        Views::LinesSharedWithMember.new(**Models::MembersSharingLines.of(@project, member).facts_beside(map))
      end
    end
  end
end

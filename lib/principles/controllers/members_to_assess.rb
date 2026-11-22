# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/carried_member"
require_relative "../models/check_since_last_audit"
require_relative "../models/open_findings_elsewhere"
require_relative "../views/acknowledged_since_last_audit"
require_relative "../views/read_the_change"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The members a full audit's request lists, which Audit hands over for start-audit: each as the agent assesses
    # it, beside what the principle's audit record says of it since the last full audit.
    class MembersToAssess < Command
      # The members a full audit's request lists, each as the agent assesses it, and the findings other principles
      # leave open on members sharing their lines, each once, which each member's mapped_elsewhere names by id.
      class Listing
        #: Array[Hash[String, untyped]]
        attr_reader :members

        #: Array[Hash[String, untyped]]
        attr_reader :open_findings_elsewhere

        #: (members: Array[Hash[String, untyped]], open_findings_elsewhere: Array[Hash[String, untyped]]) -> void
        def initialize(members:, open_findings_elsewhere:)
          @members = members
          @open_findings_elsewhere = open_findings_elsewhere
          freeze
        end
      end

      # principle_id names the principle whose members are listed, against its audit record now.
      #: (Models::Project, tool: RunningTool, principle_id: String) -> void
      def initialize(project, tool:, principle_id:)
        super(project, tool: tool)
        @principle_id = principle_id
        @record = @audit_records.find(principle_id) #: Models::AuditRecord?
        @completed = @record&.last_completed #: Models::AuditRecord?
        @checks = Models::CheckSinceLastAudit.new(principle_history: principle_history(principle_id),
                                                  record: @record) #: Models::CheckSinceLastAudit
      end

      # Each member of audit's map as the assessment request shows it, located as current has it: id, role, lines,
      # the evidence that locates it and the check that enforces it, if any, with whether the last audit already had
      # it run, the edits to it acknowledged since that audit, its last assessment carried forward by audit, or why
      # it is judged again with the command that shows its file's edits since that audit, and the other
      # principles' members sharing its lines, beside the findings their principles leave open on them.
      #: (Models::Audit, Models::MemberSnapshots) -> Listing
      def listed(audit, current)
        map = audit.map
        carried = carried_assessments(audit)
        elsewhere = elsewhere(map, current)
        members = map.members_shown.map { |fields| member_listed(fields, carried, elsewhere, current) }
        Listing.new(members: members, open_findings_elsewhere: elsewhere_listed(elsewhere, current))
      end

      private

      # One member of the map, from its fields there, as the request lists it: located as current has it, with its
      # check, the edits acknowledged since the last full audit, its carried assessment or why it is judged again,
      # and the other principles' members sharing its lines.
      #: (Hash[String, untyped], Models::CarriedAssessments, Models::OpenFindingsElsewhere, Models::MemberSnapshots)
      #|  -> Hash[String, untyped]
      def member_listed(fields, carried, elsewhere, current)
        member = Models::Member.new(fields)
        judged = carried(member, carried, elsewhere)
        located(member, current).merge(checked(member), acknowledged(fields), judged,
                                       changed_since(fields, judged, current), shared_lines(member, elsewhere))
      end

      # Each finding elsewhere names, once, with each evidence item's lines beside this audit's members, where current
      # locates them; the project locates each item now.
      #: (Models::OpenFindingsElsewhere, Models::MemberSnapshots) -> Array[Hash[String, untyped]]
      def elsewhere_listed(elsewhere, current)
        elsewhere.listed(current.audited_lines) { |locator| @project.located_text(locator) }
      end

      # The other principles' members sharing a line with each member of map where current locates it, with the
      # findings their records leave open on them, each record read once. The request id hashes this
      # principle's members, not other maps or their records: another principle changing after the request is its
      # own audit to judge, and does not make this one stale.
      #: (Models::Principle, Models::MemberSnapshots) -> Models::OpenFindingsElsewhere
      def elsewhere(map, current)
        sharing = map.members.ids.to_h do |id|
          [id, Models::MembersSharingLines.new(@project, current.of(id), id: id).elsewhere(except: @principle_id)]
        end
        Models::OpenFindingsElsewhere.of(sharing, @audit_records)
      end

      # The other principles' members sharing a line with member, each with its role there, so a contradiction
      # between the two maps shows in this audit, naming the findings that principle leaves open on it, so one
      # problem is not raised under both; nothing when there are none.
      #: (Models::Member, Models::OpenFindingsElsewhere) -> Hash[String, untyped]
      def shared_lines(member, elsewhere)
        Views::LinesSharedWithMember.new(mapped_elsewhere: elsewhere.beside(member.id)).to_h
      end

      # The member's last assessment carried forward, with whether any evidence it cited changed since and, in git,
      # whether its file changed since the last full audit's base commit, outside the member, whose own text did not;
      # or why it is judged again. These are facts: the agent may re-judge any carried member. flagged says
      # whether any fires, or another principle leaves a finding open on its lines, so the request prints the member
      # whole rather than compactly.
      #: (Models::Member, Models::CarriedAssessments, Models::OpenFindingsElsewhere) -> Hash[String, untyped]
      def carried(member, carried, elsewhere)
        shown = carried.shown(member.id) { |locator, sha| evidence_changed?(locator, sha) }
        kept = shown["carried_forward"] or return shown

        Models::CarriedMember.new(kept, file_changed_outside_member: file_changed_outside(member),
                                        open_elsewhere: elsewhere.open_beside?(member.id),
                                        open_here: @record&.open_ids_on(member.key) || []).shown
      end

      # Whether member's file changed since the last full audit's base commit; nil with no such commit, as outside git.
      #: (Models::Member) -> bool?
      def file_changed_outside(member)
        base = @completed&.base_commit or return

        @history.commits_since(base, member.path).any?
      end

      # Whether the evidence at locator no longer hashes to sha, or can no longer be found.
      #: (Models::Locator, String) -> bool
      def evidence_changed?(locator, sha)
        snapshot(locator).sha256 != sha
      rescue Error
        true
      end

      # The member as the request names and locates it: id, role, evidence and its lines now.
      #: (Models::Member, Models::MemberSnapshots) -> Hash[String, untyped]
      def located(member, current)
        { "id" => member.id, "role" => member.role, "evidence" => [member.reference] }
          .merge(current.of(member.id).lines)
      end

      # The command that shows the edits to a member judged again since the last full audit's base commit: to its
      # own lines, where current locates them, for part of a file at the same path then and now; else to its file,
      # over its path then and now. Nothing for a member carried forward, or with no such commit, as outside git or
      # before any full audit.
      #: (Hash[String, untyped], Hash[String, untyped], Models::MemberSnapshots) -> Hash[String, untyped]
      def changed_since(fields, judged, current)
        base = @completed&.base_commit
        return {} unless judged["judge_because"] && base

        member = Models::Member.new(fields)
        paths = principle_history(@principle_id).paths_from(base, member.key, fields)
        lines = member.traced_lines(paths, current.of(member.id).lines)
        { "read_the_change" => Views::ReadTheChange.new(since: base, paths:, lines:).to_s }
      end

      # The edits to member acknowledged since the last full audit, which this audit judges together, with
      # its lines then and now; its read_the_change shows the whole change.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def acknowledged(fields)
        last = @completed or return {}

        member = Models::Member.new(fields)
        made = last.members.acknowledgements_for(member.key)
        return {} if made.empty?

        base = last.base_commit.to_s
        lines = @project.member_lines_since_last_audit(member.locator, since: base).shown
        since = Views::AcknowledgedSinceLastAudit.new(last_audited_commit: base, member_lines: lines,
                                                      acknowledgements: made)
        { "acknowledged_since_last_audit" => since.to_h }
      end

      #: (Models::Member) -> Hash[String, untyped]
      def checked(member)
        hidden = member.check_hidden_characters
        @checks.entry(member).merge(hidden.empty? ? {} : { "check_hidden_characters" => hidden })
      end
    end
  end
end

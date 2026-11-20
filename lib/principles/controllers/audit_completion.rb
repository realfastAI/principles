# typed: strict
# frozen_string_literal: true

require "time"
require_relative "command"
require_relative "../models/audit"
require_relative "../models/commits_since_base"
require_relative "../models/other_principles"
require_relative "../views/prior_finding_decisions_result"

require_relative "../views/answered_request"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # A full audit's record: the open record a correction request leaves outside git, and the last step, which
    # submit-answer reaches from an assessment with no findings or from a correction, with the record it writes,
    # the files to commit and what landed since the base commit.
    class AuditCompletion < Command
      # map_changes are the changes a correction declared to the map, which name the map file to commit.
      # replacing is the revision of the last completed record when the request that completes the audit was
      # printed, which refuses to replace a record changed since. read_back_from is the record a correction
      # read the audit's assessment back from, which, when completed, only an identical retry completes again.
      #: (Models::Project, tool: RunningTool, ?map_changes: Models::DeclaredMapChanges?,
      #|  ?replacing: Models::LastCompletedRevision?, ?read_back_from: Models::AuditRecord?) -> void
      def initialize(project, tool:, map_changes: nil, replacing: nil, read_back_from: nil)
        super(project, tool: tool)
        @map_changes = map_changes #: Models::DeclaredMapChanges?
        @replacing = replacing #: Models::LastCompletedRevision?
        @read_back_from = read_back_from #: Models::AuditRecord?
      end

      # The completed result, and the record change it makes, not yet written.
      # Each prior finding's decision is applied: a kept one stays in the record, and a closed one is reported.
      #: (Models::AuditStart, Models::Audit, Array[Models::Disposition], Array[untyped], Models::DecidedPriorFindings)
      #|  -> [untyped, Array[Models::AuditRecord]]
      def completed(start, audit, dispositions, findings, decided)
        written = record(start, audit.outcomes(findings, dispositions, decided), "completed", audit.now)
        changes = @audit_records.changes(written)
        @replacing&.confirm_writable(audit.id, @audit_records.find(audit.id), changes)
        audit.confirm_read_back(@read_back_from, changes)
        [Views::AnsweredRequest.new(completion_result(start, audit, dispositions, decided, written)), changes]
      end

      # The record an audit writes, made now, saying what its assessments answered, with each assessment carried
      # forward taken from the record it replaces, and the release of principles it ran under when its
      # principle keeps one.
      #: (Models::AuditStart, Array[untyped], String, Hash[String, String], ?Models::AuditRecord?)
      #|  -> Models::AuditRecord
      def record(start, findings, status, members, last_completed = nil)
        Models::AuditRecord.written(start, status: status, audited_at: Time.now.utc.iso8601, members: members,
                                           findings: findings)
                           .judged(start.judged_against(Views::AssessmentRequest.question))
                           .carrying(@audit_records.find(start.id)).packaged(@tool.release_kept_by(start.map))
                           .keeping(last_completed)
      end

      private

      # What the completed audit prints: its resolved and open findings, as the record it writes holds them, so they
      # agree with list-open-findings; what it changed; each prior finding's decision; and, while
      # principles is not set up, the offer to set it up.
      #: (Models::AuditStart, Models::Audit, Array[Models::Disposition], Models::DecidedPriorFindings,
      #|  Models::AuditRecord) -> untyped
      def completion_result(start, audit, dispositions, decided, written)
        decisions = Views::PriorFindingDecisionsResult.new(kept_ids: decided.kept_ids, closed: decided.closed,
                                                           changed: decided.changed)
        completed = audit_result.completion(principle_id: audit.id, resolved: written.resolved_ids(decided),
                                            open: written.open_ids,
                                            changes: changes(start, audit, dispositions, written), decisions: decisions)
        offering_set_up(completed)
      end

      # completed, with the offer to set principles up while it is not, and outside the plugin, whose hooks report
      # changed members already, the offer of the hook entries that do.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def offering_set_up(completed)
        return completed if @principles.set_up?

        hooks = !@tool.runs_from.session_start_hook_in_this_session?
        audit_result.offering_set_up(completed, hooks: hooks)
      end

      # What the audit changed in the project: the files to commit, in git the commits since the base, the
      # other principles whose members its fixes changed, and the members its correction added (T69).
      #: (Models::AuditStart, Models::Audit, Array[Models::Disposition], Models::AuditRecord) -> Views::AuditChanges
      def changes(start, audit, dispositions, written)
        changed = audit.changed_files(dispositions)
        added = start.added(now: audit.now)
        map = @map_changes&.files_to_commit(@principles.file(audit.id), added: added) || []
        files = @audit_records.files_to_commit(written, changed + map, start.reported)
        Views::AuditChanges.new(files_to_commit: files, landed: landed_since_base(start, audit), added: added,
                                other_changed: other_changed(audit, changed),
                                cited_files_missing: @audit_records.cited_files_missing(written))
      end

      # Each other principle with a member in paths, the files this audit's fixes changed, whose own text now
      # differs from what this tool last knew of it or whose reference broke, as list-member-problems reports it.
      # A map this tool
      # cannot read names none here; list-member-problems reports it.
      #: (Models::Audit, Array[String]) -> Array[Views::PrincipleWithChangedMembers]
      def other_changed(audit, paths)
        Models::OtherPrinciples.of(@project, but: audit.id).changed_or_broken_in(paths).map do |id, changed|
          Views::PrincipleWithChangedMembers.new(principle_id: id, members: changed.map(&:to_h))
        end
      end

      # In git, what landed since the base commit, as the completed result prints it; nil outside git.
      #: (Models::AuditStart, Models::Audit) -> Views::LandedSinceBase?
      def landed_since_base(start, audit)
        landed = commits_since_base(start, audit) or return nil
        Views::LandedSinceBase.new(commits_by_member: landed.by_member, head_past_base: landed.head_past_base)
      end

      # In git, for each member that changed during the audit, the commits since the base commit that touched
      # its file, so the owner can see how each fix landed (alpha feedback A4), and HEAD now. nil outside git.
      #: (Models::AuditStart, Models::Audit) -> Models::CommitsSinceBase?
      def commits_since_base(start, audit)
        base = start.base or return nil
        by_member = start.changed(now: audit.now).to_h do |member|
          [member, @history.commits_since(base, audit.path_of(member))]
        end
        Models::CommitsSinceBase.new(base: base, head: @history.head, by_member: by_member)
      end
    end
  end
end

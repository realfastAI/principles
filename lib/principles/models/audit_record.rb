# typed: strict
# frozen_string_literal: true

require_relative "audit_start"
require_relative "cited_files"
require_relative "decided_prior_findings"
require_relative "open_finding"
require_relative "principles_package"
require_relative "recorded_findings"
require_relative "record_format"
require_relative "recorded_members"
require_relative "json_digest"
require_relative "finding_decision"
require_relative "../data/schema_check"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The committed record of a principle's last audit: what it began from, each member's hash when it was
    # made and each finding's outcome with its problem. Outside git it also keeps the hashes the audit
    # began from, which git keeps otherwise, and an open record keeps the last completed one, whose deferred
    # and accepted findings the next audit must still decide.
    class AuditRecord
      # The record an audit that began at start writes, with each member's hash, the result reported for its
      # check, if any, and each finding's outcome. The hashes the audit began from are kept only outside
      # git, where start has no base commit.
      #: (AuditStart, status: String, audited_at: String, members: Hash[String, String], findings: Array[untyped])
      #|  -> AuditRecord
      def self.written(start, status:, audited_at:, members:, findings:)
        fields = { "principle_id" => start.id, "status" => status, "map_version" => start.map_version,
                   "base_commit" => start.base, "audited_at" => audited_at,
                   "members" => start.recorded(members, assessed_at: audited_at), "findings" => findings }
        new(start.base ? fields : fields.merge("base_members" => start.before))
      end

      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields.freeze #: Hash[String, untyped]
        @members = RecordedMembers.new(fields.fetch("members")) #: RecordedMembers
        freeze
      end

      # The record with only the fields this tool knows, for printing.
      #: () -> Hash[String, untyped]
      def shown
        Data::SchemaCheck.new("audit-record").known(@fields)
      end

      # The record as its file holds it.
      #: () -> Hash[String, untyped]
      def to_h
        @fields
      end

      # The record as this copy writes it, as RecordFormat stamps it. Only a write stamps it, so a record read without
      # a format keeps its revision.
      #: () -> Hash[String, untyped]
      def stamped = RecordFormat.new(@fields).stamped

      # A digest of the whole record. A correction carries the last completed record's from when its request was
      # printed, so it is refused once that record changed. A formatter that only reorders its keys changes
      # neither what the record says nor its revision, as same_as? already compares it.
      #: () -> String
      def revision = JsonDigest.new(@fields).to_s

      #: () -> String
      def principle_id
        @fields.fetch("principle_id")
      end

      # A digest of what the record says of each member, apart from when its assessment was made: an open record's
      # assessment, which its correction's basis carries so the correction is refused once the record changed.
      #: () -> String
      def assessment_digest = JsonDigest.new(members.undated).to_s

      # The hashes the audit began from, kept outside git only.
      #: () -> Hash[String, String]?
      def base_members
        @fields["base_members"]
      end

      # Whether other says what this record says, apart from when it and its assessments were made and the format
      # stamped when it is written.
      #: (AuditRecord?) -> bool
      def same_as?(other)
        !other.nil? && other.undated == undated
      end

      # What this record says as it is written, without when it and each of its assessments were made.
      #: () -> Hash[String, untyped]
      def undated = stamped.except("audited_at").merge("members" => members.undated)

      # The commit the audit began from, or nil outside git.
      #: () -> String?
      def base_commit
        @fields["base_commit"]
      end

      # The record's status, when and from which commit it was made, and whether the map changed since.
      #: (map_version: String) -> Hash[String, untyped]
      def last_audit(map_version:)
        { "status" => @fields["status"], "audited_at" => @fields["audited_at"], "base_commit" => @fields["base_commit"],
          "map_changed" => @fields["map_version"] != map_version }
      end

      # Completion certainty for optional mapping feedback; the record owns its format and kept history.
      #: () -> bool
      def known_no_completed_audit? = !RecordFormat.new(@fields).newer? && last_completed.nil?

      # Whether the audit this record describes completed, rather than being left open outside git.
      #: () -> bool
      def completed?
        @fields["status"] == "completed"
      end

      # Whether the audit this record describes is open: its assessment kept and its correction not yet answered.
      #: () -> bool
      def open? = !completed?

      # Whether this record is open on a completed audit it keeps: a later full audit waiting on its correction.
      #: () -> bool
      def open_after_a_completed_audit? = open? && !last_completed.nil?

      # This open record, keeping the last completed record it replaces outside git, so the next audit still
      # decides that record's findings; itself when there is none.
      #: (AuditRecord?) -> AuditRecord
      def keeping(last_completed)
        last_completed ? AuditRecord.new(@fields.merge("last_completed" => last_completed.to_h)) : self
      end

      # This open record, keeping the correction its assessment's findings opened, its request_id and basis as
      # printed, so show-open-correction prints it again.
      #: (String, Hash[String, untyped]) -> AuditRecord
      def correcting(request_id, basis)
        AuditRecord.new(@fields.merge("correction" => { "request_id" => request_id, "basis" => basis }))
      end

      # The correction an open record keeps, its request_id and basis, or nil when it keeps none, as one an earlier
      # release wrote.
      #: () -> Hash[String, untyped]?
      def correction = (@fields["correction"] if open?)

      # This record, saying what its assessments were judged against, as AuditStart#judged_against digests it.
      #: (String) -> AuditRecord
      def judged(against) = AuditRecord.new(@fields.merge("judged_against" => against))

      # This record, keeping the release of principles its audit ran under, when the principle keeps one.
      #: (PrinciplesPackage?) -> AuditRecord
      def packaged(package) = package ? AuditRecord.new(@fields.merge("principles_package" => package.to_h)) : self

      # The release of principles its audit ran under, or nil when it kept none.
      #: () -> PrinciplesPackage?
      def package = PrinciplesPackage.kept(@fields["principles_package"])

      # Whether this record kept its members' assessments, which an older record did not.
      #: () -> bool
      def kept_assessments? = !@fields["judged_against"].nil?

      # Whether this record's assessments answered what against digests, as AuditStart#judged_against does.
      #: (String) -> bool
      def judged_against?(against) = @fields["judged_against"] == against

      # This record with each assessment its answer carried forward taken from last, the record it replaces.
      #: (AuditRecord?) -> AuditRecord
      def carrying(last)
        AuditRecord.new(@fields.merge("members" => members.carrying(last&.last_completed&.members).to_h))
      end

      # The last completed audit's record: this one, or the one an open record keeps, or nil.
      #: () -> AuditRecord?
      def last_completed
        return self if completed?

        kept = @fields["last_completed"]
        kept ? AuditRecord.new(kept) : nil
      end

      # Whether it holds a completed audit other than written, a record just completed, so written is not the first
      # to complete; a retry of written reads written back, so it is the first still.
      #: (AuditRecord) -> bool
      def completed_other_than?(written) = last_completed&.then { !it.same_as?(written) } || false

      # This record with the member known by key moved to change's to_sha256, and change kept beside it.
      # Nothing else changes: the map version, base commit and findings stay the audit's own.
      # check_result is the result reported for the member's check, which replaces the one the record kept.
      #: (String, Hash[String, untyped], ?check_result: Hash[String, untyped]?) -> AuditRecord
      def acknowledged(key, change, check_result: nil)
        AuditRecord.new(@fields.merge("members" => members.acknowledged(key, change, check_result:).to_h))
      end

      # This record with each decision applied at at to the finding it names.
      #: (Array[FindingDecision], at: String) -> AuditRecord
      def decided(decisions, at:)
        AuditRecord.new(@fields.merge("findings" => findings.decided(decisions, at: at).to_a))
      end

      # Each finding the last completed audit deferred or accepted, which the next full audit must decide:
      # this record's own, or, while it is open outside git, those of the completed record it keeps, since its own
      # wait on its correction. The one owner of which record's findings are open.
      #: () -> Array[OpenFinding]
      def left_open
        return findings.left_open if completed?

        last_completed&.left_open || []
      end

      # The ids of the findings it leaves open, as list-open-findings lists them: deferred or accepted, its own and any
      # prior finding kept.
      #: () -> Array[String]
      def open_ids = left_open.map(&:id)

      # The ids of the findings it leaves open whose action is action, deferred or accepted, which a completed
      # audit's result names apart.
      #: (String) -> Array[String]
      def left_open_ids(action) = left_open.select { it.action == action }.map(&:id)

      # The ids of the findings it leaves open on the member known by key, which the next full audit decides beside
      # it.
      #: (String) -> Array[String]
      def open_ids_on(key) = left_open.select { it.on?(key) }.map(&:id)

      # The ids of the findings its audit resolved: those it fixed, and each prior finding decided resolved, never
      # one withdrawn.
      #: (DecidedPriorFindings) -> Array[String]
      def resolved_ids(decided)
        findings.fixed_ids + decided.resolved_ids
      end

      # Each finding left open, as list-open-findings prints it.
      #: () -> Array[Hash[String, untyped]]
      def open_findings = left_open.map(&:listed)

      # Each finding left open, as the next full audit's request lists it.
      #: () -> Array[Hash[String, untyped]]
      def prior_findings = left_open.map(&:for_next_audit)

      # The path of each file this record points at, through its assessments' evidence and its findings' evidence
      # and write-ups, which a clone must hold for the record to be checked there.
      #: () -> Array[String]
      def cited_paths = (members.cited_paths + findings.cited_paths).uniq

      # The files this record cites, as history holds them now: which go with it when its completed audit is
      # committed, compared with HEAD only in git, and which no longer exist.
      #: (ProjectHistory) -> CitedFiles
      def cited_files(history) = CitedFiles.new(cited_paths, history, in_git: !base_commit.nil?)

      # The members this record assessed, each with its hash, check, loading decision and acknowledgements.
      #: RecordedMembers
      attr_reader :members

      # The command this record ran for the member known by key's check, as its RecordedMembers answers it, or nil
      # when it gave that check no exit status.
      #: (String) -> String?
      def check_run_for(key) = members.check_run_for(key)

      # The line saying what the review of the check this record ran for the member known by key rested on, with the
      # date it was first kept: its own review_basis_since, or else this record's audited_at, which dates a line kept
      # here first. Nothing when the record ran no check for it or kept no line.
      #: (String) -> Hash[String, untyped]
      def check_review_for(key)
        kept = members.check_review_as_kept(key)
        return {} unless kept.key?("review_basis")

        { "review_basis_since" => @fields["audited_at"] }.merge(kept)
      end

      # That line as an answer keeping it carries it into the record it writes: as check_review_for dates it, from a
      # completed record; from an open one as kept, since the audit completing it dates a line first kept there, so
      # answering the same assessment again records the line as the first answer did.
      #: (String) -> Hash[String, untyped]
      def check_review_carried_for(key) = completed? ? check_review_for(key) : members.check_review_as_kept(key)

      private

      # The findings its own audit recorded, whatever it did about each, with the principle, audit time and members
      # it recorded them under.
      #: () -> RecordedFindings
      def findings
        RecordedFindings.new(@fields.fetch("findings"), principle_id: principle_id, audited_at: @fields["audited_at"],
                                                        members: members)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "json"

require_relative "../error"
require_relative "../data/audit_files"
require_relative "audit_record"
require_relative "audit_entry_protecting_map"
require_relative "member_hashes_as_written"
require_relative "recorded_hashes"
require_relative "project_history"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Every principle's audit record, loaded and saved through Data::AuditFiles, and read as a commit held it
    # through ProjectHistory.
    class AuditRecords
      #: (Data::AuditFiles, ProjectHistory) -> void
      def initialize(files, history)
        @files = files
        @history = history
      end

      # The file id's record was in at commit, and that record, or nil when commit holds it in neither the folder
      # nor its earlier name, as outside git. It is read only at a commit an agent names; nothing walks history.
      #: (String, String) -> [String, AuditRecord]?
      def at(id, commit)
        [file(id), earlier_file(id)].each do |path|
          text = @history.at(commit).text(path) or next
          return [path, AuditRecord.new(@files.parse(id, text) { refuse_unreadable(it, path) })]
        end
        nil
      end

      # id's record, or nil when it has none; Data::AuditFiles refuses one that is unparseable, and one its schema
      # refuses, unless a later copy wrote it.
      #: (String) -> AuditRecord?
      def find(id)
        fields = @files.read(id) { refuse_unreadable(it, file(id)) }
        fields && AuditRecord.new(fields)
      end

      # One exact historical selection, without a routed lookup or a format stamp.
      #: (String, String) -> AuditRecord
      def parsed_history(id, text)
        fields = @files.parse(id, text) { refuse_unreadable(it, file(id)) }
        refuse_unreadable(fields, file(id))
        record = AuditRecord.new(JSON.parse(JSON.generate(fields), freeze: true))
        return record if record.principle_id == id && record.completed?

        raise Error.new("invalid_audit_record", "#{file(id)} is not a completed record of #{id}",
                        "Preserve this record and inspect its identity and status before changing an ID.", file(id))
      end

      # Optional mapping feedback: a missing record is known absence; unreadable records leave this unknown.
      #: (String) -> bool
      def known_no_completed_audit?(id)
        audit = find(id) or return true
        audit.known_no_completed_audit?
      rescue Error
        false
      end

      # The findings id's record leaves open: none when it has no record, and none when its record cannot be read,
      # which list-member-problems reports, so a command reading other principles' findings beside its own is not
      # refused for theirs.
      #: (String) -> Array[OpenFinding]
      def left_open_or_none(id)
        find(id)&.left_open || []
      rescue Error
        []
      end

      # Refuses to let this copy, at version, rewrite id's record when a later copy wrote it at a newer format,
      # read afresh so a record that lands mid-audit is caught too.
      #: (String, version: String) -> void
      def refuse_newer(id, version:)
        record = find(id) or return
        RecordFormat.new(record.to_h).refuse_rewrite(file(id), version: version)
      end

      # The format of id's record when a later copy wrote it, read whether or not this copy's schema accepts it; nil
      # when it has none, is not newer, or is refused for another reason, which reading it reports.
      #: (String) -> RecordFormat?
      def newer_format(id)
        fields = @files.read(id) { |raw| return RecordFormat.newer_of(raw) }
        fields && RecordFormat.newer_of(fields)
      rescue Error
        nil
      end

      # The member hashes id's record holds, which its members are compared with: the record's own when this copy can
      # read it, and as written when its schema refuses one a later copy wrote, marked waiting when a later copy wrote
      # it, so the comparison is read-only; none when it has no record.
      #: (String) -> RecordedHashes
      def hashes_to_compare(id)
        audit = find(id) or return RecordedHashes::NONE
        audit.members.hashes(waiting: RecordFormat.new(audit.to_h).newer?)
      rescue RecordFormat::NewerFormatError
        RecordedHashes.new(member_hashes_as_written(id).by_key, waiting: true)
      end

      # id's record if this copy can read it; nil when it has none, or a later copy wrote it in a form this copy
      # cannot read, whose audits wait on an upgrade.
      #: (String) -> AuditRecord?
      def readable(id)
        find(id)
      rescue RecordFormat::NewerFormatError
        nil
      end

      # The record of each of ids that has one.
      #: (Array[String]) -> Array[AuditRecord]
      def of(ids) = ids.filter_map { |id| find(id) }

      # The record of each of ids that this copy can read, leaving out one a later copy wrote that it cannot, so a
      # read across principles is not refused for that one, whose audits wait on an upgrade.
      #: (Array[String]) -> Array[AuditRecord]
      def readable_of(ids)
        ids.filter_map { readable(it) }
      end

      # id's record, refused when it has none.
      #: (String) -> AuditRecord
      def fetch(id)
        find(id) || raise(Error.new("unknown_audit", "#{id} has no audit record",
                                    "To audit it: #{Error::EXECUTABLE} start-audit #{id}", file(id)))
      end

      #: (String) -> bool
      def exist?(id)
        @files.exist?(id)
      end

      #: (String, ?confirmed: bool) -> void
      def refuse_map_removal(id, confirmed: false)
        return unless @files.entry?(id)
        return if confirmed

        raise AuditEntryProtectingMap.new(id, file(id)).refusal
      end

      # The record as a change to write, unless it says what the record on disk says, apart from when.
      #: (AuditRecord) -> Array[AuditRecord]
      def changes(record)
        record.same_as?(find(record.principle_id)) ? [] : [record]
      end

      # What record's completed audit asks to commit: its own file, then the files the record says go with it, of
      # changed and those it cites, with what reported cites that the record does not keep.
      #: (AuditRecord, Array[String], ?AssessmentReport) -> Array[String]
      def files_to_commit(record, changed, reported = AssessmentReport::NONE)
        [file(record.principle_id), *record.cited_files(@history).committed_with(changed, reported)]
      end

      # Each file record cites that no longer exists, which files_to_commit leaves out.
      #: (AuditRecord) -> Array[String]
      def cited_files_missing(record) = record.cited_files(@history).missing

      # Writes record's file and names it, relative to the project.
      #: (AuditRecord) -> String
      def save(record)
        id = record.principle_id
        @files.write(id, record.stamped)
        file(id)
      end

      # The file id's record is kept in, relative to the project.
      #: (String) -> String
      def file(id)
        @files.relative(id)
      end

      # The file id's record was kept in under the folder's earlier name, relative to the project.
      #: (String) -> String
      def earlier_file(id)
        @files.earlier_relative(id)
      end

      private

      # The member hashes of id's record as a later copy wrote it, read without this copy's schema, which refuses it;
      # none when it cannot be parsed at all.
      #: (String) -> MemberHashesAsWritten
      def member_hashes_as_written(id)
        fields = @files.read(id) { |raw| return MemberHashesAsWritten.new(raw) }
        MemberHashesAsWritten.new(fields)
      rescue Error
        MemberHashesAsWritten.new(nil)
      end

      # Refuses fields, a record at file the schema refused, as one a later copy wrote when its format says so, so
      # its repair is never to repair or restore a record that is not broken.
      #: (untyped, String) -> void
      def refuse_unreadable(fields, file)
        RecordFormat.new(fields).refuse_unreadable(file) if fields.is_a?(Hash)
      end
    end
  end
end

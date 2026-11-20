# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"
require_relative "schema_check"
require_relative "principles_subfolder"
require_relative "json_text"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The audit records: one JSON file per principle under .principles/audits/, committed in the audited
    # repository beside its map. A record holds the last audit's base commit, each member's hash and each
    # finding's id, members and action, never the agent's prose.
    class AuditFiles
      # The key a record named its principle under before the rename to principles.
      EARLIER_ID_KEY = "memeplex_id"

      #: (PrinciplesSubfolder) -> void
      def initialize(directory)
        @directory = directory
      end

      # Which of the folder and its earlier name hold this subfolder.
      #: () -> Array[String]
      def held_in
        @directory.held_in
      end

      #: (String) -> bool
      def exist?(id)
        @directory.exist?(id)
      end

      # Any current entry, including an unreadable record or dangling link, protects a map from removal.
      #: (String) -> bool
      def entry?(id) = @directory.entry?(id, shown_as: relative(id))

      # The record of id's last audit, or nil when it has none, checked against its schema, handing the block
      # a record the schema refuses, as parse does.
      #: (String) ?{ (untyped) -> void } -> Hash[String, untyped]?
      def read(id, &)
        return unless exist?(id)

        parse(id, @directory.read(id, shown_as: relative(id)), &)
      end

      # The record of id from its text, with an older version's key upgraded, checked against its schema. A
      # record the schema refuses is handed to the block first, which may refuse it otherwise, as a model does one a
      # later copy wrote.
      #: (String, String) ?{ (untyped) -> void } -> Hash[String, untyped]
      def parse(id, text, &)
        record = upgraded(JsonText.new(text).parsed)
        problems = SchemaCheck.new("audit-record").problems(record)
        return record if problems.empty?

        yield record if block_given?
        raise Error.new("invalid_audit_record", "#{relative(id)} is not in the shape this tool writes",
                        "Repair each field listed, or restore the record from version control.", relative(id),
                        fields: problems)
      rescue JSON::ParserError => e
        raise Error.new("unparseable_audit", e.message,
                        "Repair this audit record or restore it from version control.", relative(id))
      end

      #: (String, Hash[String, untyped]) -> void
      def write(id, record)
        @directory.write(id, "#{JSON.pretty_generate(record)}\n")
      end

      #: (String) -> String
      def relative(id)
        File.join(PrinciplesSubfolder::FOLDER, "audits", "#{id}.json")
      end

      # Where record id was kept before the folder took its name now, so it can be read at earlier commits.
      #: (String) -> String
      def earlier_relative(id)
        File.join(PrinciplesSubfolder::EARLIER_FOLDER, "audits", "#{id}.json")
      end

      private

      # A record an older version wrote names its principle under EARLIER_ID_KEY, in the record and in the last
      # completed record an open one keeps. It is read under principle_id, in the same place, so the next save
      # writes the new key only; when both are present, principle_id is kept.
      #: (untyped) -> untyped
      def upgraded(record)
        return record unless record.is_a?(Hash)

        renamed = renamed_id(record)
        kept = renamed["last_completed"]
        kept.is_a?(Hash) ? renamed.merge("last_completed" => renamed_id(kept)) : renamed
      end

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def renamed_id(record)
        current = record.key?("principle_id") ? record.except(EARLIER_ID_KEY) : record
        current.to_h { |key, value| [key == EARLIER_ID_KEY ? "principle_id" : key, value] }
      end
    end
  end
end

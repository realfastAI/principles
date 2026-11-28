# typed: strict
# frozen_string_literal: true

require_relative "acknowledgements_offered"
require_relative "record_waiting_on_an_upgrade"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What list-member-problems' result says beside the report the models check, as plain values: the older files
    # left unread, by principle the files to commit so its members with no baseline gain one, and those an audit of
    # it refuses until they are committed, by the principles that acknowledge them together the changed members a
    # one-member audit may judge, and each principle whose record a later copy wrote, whose members are not checked.
    class ProblemFacts
      #: Array[String]
      attr_reader :not_read

      #: Hash[String, Array[String]]
      attr_reader :no_baseline_files

      #: Hash[String, Array[String]]
      attr_reader :audit_files

      #: AcknowledgementsOffered
      attr_reader :acknowledgeable

      #: Array[RecordWaitingOnAnUpgrade]
      attr_reader :waiting

      #: (?not_read: Array[String], ?no_baseline_files: Hash[String, Array[String]],
      #|  ?audit_files: Hash[String, Array[String]], ?acknowledgeable: AcknowledgementsOffered,
      #|  ?waiting: Array[RecordWaitingOnAnUpgrade]) -> void
      def initialize(not_read: [], no_baseline_files: {}, audit_files: {}, acknowledgeable: AcknowledgementsOffered::NONE,
                     waiting: [])
        @not_read = not_read
        @no_baseline_files = no_baseline_files
        @audit_files = audit_files
        @acknowledgeable = acknowledgeable
        @waiting = waiting
        freeze
      end

      # The principles waiting on an upgrade, by id.
      #: () -> Array[String]
      def waits = @waiting.map(&:principle)
    end
  end
end

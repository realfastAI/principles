# typed: strict
# frozen_string_literal: true

require "rubygems"
require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # An audit record's format: the number a copy compares with the newest it writes and rewrites without losing a
    # field, and the first release that wrote it, which a copy that does not know the format names as the update to
    # make. A record without a format is older than format 1. An open record outside git keeps the last
    # completed one whole, so that one's format counts too.
    class RecordFormat
      # The refusal of a record a later copy wrote at a format this copy cannot rewrite or read, which a read across
      # principles, or one comparing members, catches by its kind rather than its code.
      class NewerFormatError < Error; end

      # The release that first wrote each format. In the commit that adds a field an older copy would drop on a
      # rewrite, add the next format here, set by hand to the release that commit ships in, and name the field in
      # FIELD_FORMATS, so only a record carrying it moves up.
      # Add its row to prompts/docs/AUDIT_RECORD_FORMAT_HISTORY.md too.
      FIRST_RELEASES = { 1 => "0.0.4", 2 => "0.0.8", 3 => "0.1.0", 4 => "0.1.2" }.freeze #: Hash[Integer, String]
      # The format each later field needs, by its path of property names: the open record's correction, which
      # show-open-correction prints again, a finding's changes since its audit, which the next full audit shows, and a
      # write-up at a URL, which an older copy's schema refuses as broken for its missing path.
      FIELD_FORMATS = { "correction" => 2, "findings.changed_since_audit" => 3,
                        "findings.recorded_at.url" => 4 }.freeze #: Hash[String, Integer]
      # The newest format this copy writes and rewrites without losing a field; formats count up from 1.
      NEWEST = FIRST_RELEASES.size #: Integer
      FIELDS = %w[format format_first_release].freeze

      #: (untyped) -> RecordFormat?
      def self.newer_of(fields)
        format = new(fields) if fields.is_a?(Hash)
        format if format&.newer?
      end

      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields
        freeze
      end

      # The record's fields as this copy writes them, ahead of the rest the oldest format that holds them all and that
      # format's first release, worked out again on each write.
      #: () -> Hash[String, untyped]
      def stamped
        format = FIELD_FORMATS.filter_map { |path, needs| needs if holds?(@fields, path.split(".")) }.max || 1
        { "format" => format, "format_first_release" => FIRST_RELEASES.fetch(format), **@fields.except(*FIELDS) }
      end

      # Refuses a record whose format, or its kept last completed record's, is above NEWEST, before this copy, at
      # version, rewrites it and drops what it does not know. file is the record's, relative to the project.
      #: (String, version: String) -> void
      def refuse_rewrite(file, version:)
        format, release = newest_held
        return unless format > NEWEST

        refuse(file, "#{format}, first written by release #{release}; this copy, #{version}, rewrites up to " \
                     "format #{NEWEST}", update(release, version))
      end

      # Refuses a record this copy's schema refused, when a later copy wrote it, so it is not reported as invalid.
      # A read holds no version, so the repair names both ways to update.
      #: (String) -> void
      def refuse_unreadable(file)
        return unless newer?

        refuse(file, "#{number}, first written by release #{first_release}; this copy reads up to format #{NEWEST}",
               "#{update_either_way}, then run the command again.")
      end

      # Whether a later copy wrote the record, at a format above NEWEST.
      #: () -> bool
      def newer? = number > NEWEST

      # The highest format the record holds, its own or its kept last completed record's; 0 for none.
      #: () -> Integer
      def number = newest_held.first

      # The first release that wrote that format.
      #: () -> String
      def first_release = newest_held.last

      # How to update to read the record, whatever copy runs: what a read without the running version says.
      #: () -> String
      def update_either_way
        "Update the principles plugin or gem to #{first_release} or later, or a checkout or archive of principles " \
          "to a later commit"
      end

      private

      # Whether value holds the property names leads to, through any entry of an array on the way.
      #: (untyped, Array[String]) -> bool
      def holds?(value, names)
        first, *rest = names
        return true unless first
        return value.any? { holds?(it, names) } if value.is_a?(Array)
        return false unless value.is_a?(Hash) && value.key?(first)

        holds?(value[first], rest)
      end

      #: (String, String, String) -> bot
      def refuse(file, format_stated, update)
        raise NewerFormatError.new("newer_audit_record", "#{file} is format #{format_stated}",
                                   "#{update} Leave the record as it is: it is not broken.", file)
      end

      # The highest format the record holds, with the release that first wrote it.
      #: () -> [Integer, String]
      def newest_held
        kept = @fields["last_completed"]
        [@fields, kept.is_a?(Hash) ? kept : {}].map do |fields|
          [fields["format"].is_a?(Integer) ? fields["format"] : 0, fields["format_first_release"].to_s]
        end.max_by(&:first) || [0, ""]
      end

      # What to update to read release's format: a published copy to that release, a development one, whose
      # version is a prerelease, to a later commit; and a release above this copy's own may not be published yet.
      #: (String, String) -> String
      def update(release, version)
        running = Gem::Version.new(version)
        unpublished = Gem::Version.correct?(release) && Gem::Version.new(release) > running.release
        how = if running.prerelease?
                "Update this checkout or archive of principles to a later commit, then run the command again."
              else
                "Update the principles plugin or gem to #{release} or later, then run the command again."
              end
        unpublished ? "#{how} #{release} may not be published yet." : how
      end
    end
  end
end

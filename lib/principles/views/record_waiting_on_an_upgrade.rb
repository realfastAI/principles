# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One principle whose audit record a later copy wrote, at a format this copy cannot rewrite, so its audits and
    # acknowledgements wait on an upgrade, which list-member-problems states instead of offering them. The
    # session-start hook prints its line from --short's stderr, matching "audit record is format N, first written
    # by release", so a reword of that phrase changes the hook too.
    class RecordWaitingOnAnUpgrade
      # newest is the newest format this copy rewrites; update says how to update, whatever copy runs.
      #: (principle: String, format: Integer, first_release: String, newest: Integer, update: String) -> void
      def initialize(principle:, format:, first_release:, newest:, update:)
        @principle = principle
        @format = format
        @first_release = first_release
        @newest = newest
        @update = update
        freeze
      end

      #: String
      attr_reader :principle

      # As list-member-problems lists it under records_waiting_on_an_upgrade.
      #: () -> Hash[String, untyped]
      def to_h = { "principle" => @principle, **record_format }

      # As show-audit prints it beside the record.
      #: () -> Hash[String, String]
      def beside = { "record_waiting_on_an_upgrade" => to_s }

      # As list-principles marks the principle's row: the format alone, since its next_action says once how to update,
      # where the whole line on each row repeated it.
      #: () -> Hash[String, Hash[String, untyped]]
      def marker = { "record_waiting_on_an_upgrade" => record_format }

      # How to update so this copy can read the record, as one sentence.
      #: () -> String
      def update = "#{@update}."

      # The record's format and the release that first wrote it.
      #: () -> Hash[String, untyped]
      def record_format = { "format" => @format, "format_first_release" => @first_release }

      #: () -> String
      def to_s
        "#{@principle}'s audit record is format #{@format}, first written by release #{@first_release}; this copy " \
          "rewrites up to format #{@newest}, so its audits and acknowledgements wait on an upgrade. #{update}"
      end
    end
  end
end

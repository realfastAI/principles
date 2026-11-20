# typed: strict
# frozen_string_literal: true

require "time"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A time as an agent wrote it in an answer, such as a sighting's observed_at, which the record compares with
    # audited_at only in audited_at's own form: a UTC time to the second.
    class AnsweredTime
      #: (untyped) -> void
      def initialize(value)
        @value = value
        freeze
      end

      # Whether it is a UTC time in audited_at's form. Only a time that reads back as written is: Time.iso8601 takes an
      # offset or a fraction, and rolls 30 February over to March.
      #: () -> bool
      def utc?
        return false unless @value.is_a?(String)

        Time.iso8601(@value).utc.iso8601 == @value
      rescue ArgumentError
        false
      end

      # Whether it is written as a date alone, such as 2026-11-01, whether or not a calendar has that date.
      #: () -> bool
      def date_alone?
        return false unless @value.is_a?(String)

        @value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      end

      # The UTC time in audited_at's form that it names exactly, or nil when it names none: a date alone at its
      # midnight, and a time to the second with an offset as the same instant. A fraction, or a date no
      # calendar has, names none.
      #: () -> String?
      def exact_utc
        return midnight if date_alone?
        return unless @value.is_a?(String)

        time = Time.iso8601(@value)
        time.utc.iso8601 if time.iso8601 == @value
      rescue ArgumentError
        nil
      end

      # It in audited_at's form when it names a time to the second exactly, with any UTC offset, so a clock's own
      # offset is the same instant; otherwise as given, a date alone included, for its sighting to refuse.
      #: () -> untyped
      def in_audited_at_form
        return @value if date_alone?

        exact_utc || @value
      end

      # Whether it is later than time, both UTC times in audited_at's form: a sighting is made before the answer that
      # reports it, so a repair never prints one later.
      #: (String) -> bool
      def after?(time) = Time.iso8601(@value) > Time.iso8601(time)

      private

      #: () -> String?
      def midnight
        at_midnight = "#{@value}T00:00:00Z"
        at_midnight if AnsweredTime.new(at_midnight).utc?
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../prose_list"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One principle's members with no baseline, as list-member-problems' next_action says what gives them one:
    # outside git a completed audit, and in git committing the files that hold them.
    class MembersWithNoBaseline
      # because is "outside_git" or "not_committed"; audit is the start-audit command to run outside git, and
      # files the map and member files to commit in git.
      #: (id: String, count: Integer, because: String, audit: String, files: Array[String]) -> void
      def initialize(id:, count:, because:, audit:, files:)
        @id = id
        @count = count
        @because = because
        @audit = audit
        @files = files
        freeze
      end

      #: () -> String
      def to_s
        "#{@count} member#{"s" unless one?} of #{@id} #{one? ? "has" : "have"} no baseline, so whether " \
          "#{one? ? "it" : "they"} changed is not yet known.#{remedy}"
      end

      # Whether its remedy names the audit command, as it does unless committing files gives the baseline.
      #: () -> bool
      def names_a_command? = !committing?

      private

      #: () -> bool
      def one? = @count == 1

      #: () -> bool
      def committing? = @because == "not_committed" && !@files.empty?

      # What gives the members a baseline: a completed audit outside git, or in git committing the files that
      # differ from HEAD, or an audit again when none does, since every file is committed already. The
      # audit command starts a line of its own, after its purpose.
      #: () -> String
      def remedy
        return " Committing #{ProseList.new(@files)} #{gives}." if committing?

        "#{all_committed if @because == "not_committed"}\nA completed audit #{gives}: #{@audit}"
      end

      #: () -> String
      def gives = "gives #{one? ? "it" : "each"} one"

      #: () -> String
      def all_committed
        them, their, were = one? ? %w[it its was] : %w[them their were]
        " Every file holding #{them} is already committed, but no commit held #{them} where #{their} map places " \
          "#{them} when #{one? ? "it" : "they"} #{were} mapped."
      end
    end
  end
end

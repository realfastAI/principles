# typed: strict
# frozen_string_literal: true

require "shellwords"
require_relative "listed_members"
require_relative "problem_report"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A member's check that is this tool's own list-member-problems --short, which exits 3 while it lists the member
    # itself, until the acknowledgement of its edit is committed. Only a check whose words
    # map exactly to that command's is one: any other check passes on exit 0 alone.
    class ListMemberProblemsCheck
      COMMAND = "list-member-problems"
      SHORT = "--short"
      # Characters a shell reads as more than one command's words, or as a redirection or substitution, which leave
      # what ran no longer this command alone.
      SHELL_CONTROL = /[;&|<>()`$]/
      # The words that may run this tool before its executable, which is any path to `principles`.
      RUNNERS = [[], ["ruby"], %w[bundle exec]].freeze #: Array[Array[String]]

      # The check command reads as, or nil when its words do not map exactly to list-member-problems --short with at
      # most one principle id, run as this tool by any path to it, with no word of shell control.
      #: (String) -> ListMemberProblemsCheck?
      def self.of(command)
        ids = principle_ids(words_after_the_command(command))
        new(ids.first) if ids
      end

      # The words after the command name, or nil unless command runs this tool alone.
      #: (String) -> Array[String]?
      def self.words_after_the_command(command)
        words = Shellwords.split(command)
        at = words.index(COMMAND)
        words.drop(at + 1) if at && words.none? { SHELL_CONTROL.match?(it) } && this_tool?(words.take(at))
      rescue ArgumentError
        nil
      end

      # The principle ids the words after the command name give, at most one, or nil unless they are --short once and
      # that id.
      #: (Array[String]?) -> Array[String]?
      def self.principle_ids(after)
        return unless after

        ids = after - [SHORT]
        ids if after.count(SHORT) == 1 && ids.length <= 1 && ids.none? { it.start_with?("-") }
      end

      # Whether words run this tool: its executable last, after nothing or a runner.
      #: (Array[String]) -> bool
      def self.this_tool?(words)
        *runner, executable = words
        executable&.split("/")&.last == "principles" && RUNNERS.include?(runner)
      end
      private_class_method :words_after_the_command, :principle_ids, :this_tool?

      # The principle whose map the check reads, or nil for every map.
      #: String?
      attr_reader :principle_id

      #: (String?) -> void
      def initialize(principle_id)
        @principle_id = principle_id
        freeze
      end

      # What the check lists in project now, read through the report the command prints from, over the same scope:
      # each member, as its principle id and member id, and by principle the count of members no audit has assessed,
      # beside the members acknowledging names, each as its principle id and member id.
      #: (Project, principle_id: String, acknowledging: Array[[String, String]]) -> ListedMembers
      def listed(project, principle_id:, acknowledging:)
        report = ProblemReport.for(project, @principle_id)
        ListedMembers.new(listed: report.checked.fetch("members").map { it.values_at("principle", "id") },
                          principle_id:, acknowledging:, never_assessed: report.never_assessed)
      end
    end
  end
end

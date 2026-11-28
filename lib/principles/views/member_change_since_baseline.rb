# typed: strict
# frozen_string_literal: true

require_relative "read_the_change"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One member's change since its baseline, as a one-member audit's request shows it: the member's id, role and
    # evidence, the commit its baseline text is at, the commit the audit is based on, the member's own lines at
    # each, and the command that shows its change between them.
    class MemberChangeSinceBaseline
      # member holds the member's id, role and evidence; commits holds "base", HEAD, and "baseline", the commit
      # the member's baseline text is at, and "audit_base" when the baseline is later than the audit's base;
      # member_lines holds its own lines at each, or their counts when too long; first_changed_lines the first line
      # on each side the other lacks; read_the_change the command that shows the change from baseline to base.
      #: (member: Hash[String, untyped], commits: Hash[String, String], member_lines: Hash[String, untyped],
      #|  first_changed_lines: Hash[String, String], read_the_change: ReadTheChange) -> void
      def initialize(member:, commits:, member_lines:, first_changed_lines:, read_the_change:)
        @member = member
        @commits = commits
        @member_lines = member_lines
        @first_changed_lines = first_changed_lines
        @read_the_change = read_the_change
        freeze
      end

      # The first line on each side the other lacks, which an answer leaving its quotes out reads them as.
      #: Hash[String, String]
      attr_reader :first_changed_lines

      #: () -> String
      def member_id
        @member.fetch("id")
      end

      # The member's role as its map names it.
      #: () -> String
      def role = @member.fetch("role")

      #: () -> String
      def base_commit
        @commits.fetch("base")
      end

      # Whether other prints the same change as this one: the same lines and first changed lines, as one
      # member mapped by two principles does from baselines holding the same text, whatever commit each is at.
      #: (MemberChangeSinceBaseline) -> bool
      def same_change_as?(other) = other.change == change

      # The fields as the request prints them, but the change, which another principle's entry prints under
      # principle_id.
      #: (String) -> Hash[String, untyped]
      def shown_under(principle_id)
        shown = change
        to_h.reject { |field, _| shown.key?(field) }.merge("change_shown_under" => principle_id)
      end

      # The fields as the request prints them. Lines left out for their length point at read_the_change instead,
      # so the request is never silently partial.
      #: () -> Hash[String, untyped]
      def to_h
        read = @read_the_change.to_s
        lines = @member_lines.key?("omitted") ? @member_lines.merge("read_instead" => read) : with_read_instead(read)
        { "member" => @member, "baseline_commit" => @commits.fetch("baseline"), "base_commit" => base_commit,
          **@commits.slice("audit_base").transform_keys { "audit_base_commit" },
          "member_lines" => lines, "first_changed_lines" => @first_changed_lines, "read_the_change" => read }
      end

      protected

      # The fields that print the change itself, as the request prints them, which a request across principles
      # prints once for a shared member.
      #: () -> Hash[String, untyped]
      def change = to_h.slice("member_lines", "first_changed_lines")

      private

      # The member's lines, each side of their changed region, or of each of their changed regions, left out pointing
      # at read, as the whole lines do.
      #: (String) -> Hash[String, untyped]
      def with_read_instead(read)
        @member_lines.to_h do |key, value|
          case key
          when "changed_region" then [key, region_reading(value, read)]
          when "changed_regions" then [key, value.map { region_reading(it, read) }]
          else [key, value]
          end
        end
      end

      # region with each side left out pointing at read.
      #: (Hash[String, untyped], String) -> Hash[String, untyped]
      def region_reading(region, read)
        region.transform_values do |side|
          side.is_a?(Hash) && side.key?("omitted") ? side.merge("read_instead" => read) : side
        end
      end
    end
  end
end

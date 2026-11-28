# typed: strict
# frozen_string_literal: true

require_relative "first_audit"
require_relative "new_loading_scope"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What add-member's result needs to know of the map a member joined, beyond the map itself: whether its
    # principle keeps the others held, and which mapped principles it holds, which changes the step after mapping,
    # whether a full audit's correction may be open on it, so that the member may fix one of its findings, and
    # whether to repeat what to do after mapping: with a principle's first member, or in git the first since the
    # map's last commit, so members mapped in one sitting do not each repeat it.
    class MapAddedTo
      COMPLETENESS_QUESTION = "Is every carrier of the same rule mapped, and should any member belong to another " \
                              "principle? "

      # The ids of the other mapped principles this map keeps held: nil for a map that keeps none held, and empty
      # for the keeping principle's map while no other principle is mapped.
      #: Array[String]?
      attr_reader :keeps_held

      #: bool
      attr_reader :correction_may_be_open

      #: bool
      attr_reader :reminded

      #: (?keeps_held: Array[String]?, ?correction_may_be_open: bool, ?reminded: bool,
      #|  ?asks_about_completeness: bool, ?new_scope: NewLoadingScope) -> void
      def initialize(keeps_held: nil, correction_may_be_open: false, reminded: true,
                     asks_about_completeness: false, new_scope: NewLoadingScope.new)
        @keeps_held = keeps_held
        @correction_may_be_open = correction_may_be_open
        @reminded = reminded
        @asks_about_completeness = asks_about_completeness
        @new_scope = new_scope
        freeze
      end

      # This immutable reminder context with the model's decision to ask about coverage, not a completeness verdict.
      #: (asks: bool) -> MapAddedTo
      def with_completeness_question(asks:)
        MapAddedTo.new(keeps_held: @keeps_held, correction_may_be_open: @correction_may_be_open,
                       reminded: @reminded, asks_about_completeness: asks, new_scope: @new_scope)
      end

      # This immutable addition context with the model's new-scope facts, preserving its original reminder flags.
      #: (NewLoadingScope) -> MapAddedTo
      def with_loading_scope(scope)
        MapAddedTo.new(keeps_held: @keeps_held, correction_may_be_open: @correction_may_be_open,
                       reminded: @reminded, asks_about_completeness: @asks_about_completeness, new_scope: scope)
      end

      #: () -> Hash[String, untyped]
      def added_facts = @new_scope.to_h

      # The guidance after adding member, from this map's before-save reminder and correction facts.
      #: (PrintedPrinciple, member: String, invocation: Invocation, in_git: bool) -> String
      def after_member(principle, member:, invocation:, in_git:)
        "#{@new_scope.note}#{COMPLETENESS_QUESTION if @asks_about_completeness && @reminded}" \
          "#{claimed_by_a_fix(member, invocation) if @correction_may_be_open && @reminded}" \
          "#{after_adding(principle, invocation, in_git:) if @reminded}"
      end

      private

      # How an added member joins an open correction, ending its command's line.
      #: (String, Invocation) -> String
      def claimed_by_a_fix(member, invocation)
        "If you hold a correction request from submit-answer (phase correction) and this member fixes one of its " \
          "findings, name #{member} in the changed_members of the fixed disposition; the next full audit assesses " \
          "it.\nTo submit the correction instead: #{invocation.submit_answer("REQUEST_ID")}\n"
      end

      # Commit/inspection guidance and the first audit's place, once the map lists every member.
      #: (PrintedPrinciple, Invocation, in_git: bool) -> String
      def after_adding(principle, invocation, in_git:)
        "Commit #{principle.file} as it changes, so the project's history shows each change; in git, start-audit " \
          "refuses a map that is not committed.\n" \
          "To see the map so far: #{invocation.in_project("show-principle", principle.id)}\n" \
          "#{FirstAudit.new(invocation, in_git:).after_mapping(principle.id, keeps_held: @keeps_held)}"
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A carried member's kept assessment with the facts beside it that may mean the agent should judge it again,
    # and whether any fires, which decides whether a full audit's request prints the member whole or
    # compactly. Whether to judge it again stays the agent's.
    class CarriedMember
      # kept is the assessment carried forward as the request shows it, with evidence_changed;
      # file_changed_outside_member says, in git, whether its file changed since the last full audit outside it, nil
      # outside git; open_elsewhere, whether another principle leaves a finding open on a member sharing its lines;
      # open_here, the ids of the findings this principle leaves open on it.
      #: (Hash[String, untyped], file_changed_outside_member: bool?, open_elsewhere: bool, open_here: Array[String])
      #|  -> void
      def initialize(kept, file_changed_outside_member:, open_elsewhere:, open_here:)
        @kept = kept
        @file_changed_outside_member = file_changed_outside_member
        @open_elsewhere = open_elsewhere
        @open_here = open_here
        freeze
      end

      # What the request lists of the member: its carried assessment with the git fact beside it, the findings this
      # principle leaves open on it, if any, and whether a flag fires.
      #: () -> Hash[String, untyped]
      def shown
        { "carried_forward" => @kept.merge({ "file_changed_outside_member" => @file_changed_outside_member }.compact),
          **(@open_here.empty? ? {} : { "open_finding_ids" => @open_here }), "flagged" => fired? }
      end

      # Whether any flag fires: evidence the assessment cited changed, its file changed outside it, or a finding is
      # open on its lines elsewhere (review F1) or here.
      #: () -> bool
      def fired?
        @kept.fetch("evidence_changed") == true || @file_changed_outside_member == true || @open_elsewhere ||
          @open_here.any?
      end
    end
  end
end

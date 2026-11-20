# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How this tool says when a principle's work is in hand, from the activation its map stores: the phrase
    # change-activation's question carries, and that later results will share.
    class ActivationInHand
      # How the question words each value of Models::Activation#full_audit_lists.
      LISTED = {
        "session_start_members" => "The next full audit lists each member that loads at every session start " \
                                   "anyway, for you to weigh against it.",
        "none" => "Its work is in hand in every session, so a full audit lists no member to weigh against it.",
        "not_built" => "A full audit's listing of members that load outside it is not built yet."
      }.freeze #: Hash[String, String]

      #: (Hash[String, untyped]) -> void
      def initialize(activation)
        @activation = activation
        freeze
      end

      # What change-activation's question says it recorded for principle_id, and, from lists, what the next full audit
      # lists against it.
      #: (String, String) -> String
      def recorded(principle_id, lists)
        "Recorded that #{principle_id}'s work is in hand #{phrase}. #{LISTED.fetch(lists)}"
      end

      # What change-activation's question says when the map already held this activation, so nothing changed.
      #: (String) -> String
      def unchanged(principle_id)
        "#{principle_id}'s work was already in hand #{phrase}; nothing was written."
      end

      #: () -> String
      def phrase
        case @activation.fetch("when")
        when "files" then "when files matching #{@activation.fetch("files").join(", ")} are read or changed"
        when "invoked" then "when its work is invoked, as a skill or a runbook is"
        else "for all work, in every session"
        end
      end
    end
  end
end

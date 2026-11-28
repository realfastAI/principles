# typed: strict
# frozen_string_literal: true

require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What each status a member can have in the logged requests means, in one line each, printed once beside the
    # members that carry them, so the agent reads a status without guessing. not_a_carrier comes first, since a first
    # reader most often mistakes it for a gap.
    class LoggedRequestStatusMeanings
      #: () -> void
      def initialize
        freeze
      end

      # Each status, with its one-line meaning.
      #: () -> Hash[String, String]
      def to_h
        { "not_a_carrier" => Prompts.text("read-what-reached-the-context/what-not-a-carrier-means"),
          "present" => Prompts.text("read-what-reached-the-context/what-present-means"),
          "present_but_not_loaded" => Prompts.text("read-what-reached-the-context/what-present-but-not-loaded-means"),
          "absent" => Prompts.text("read-what-reached-the-context/what-absent-means"),
          "unmeasurable" => Prompts.text("read-what-reached-the-context/what-unmeasurable-means") }
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The passage setup proposes for every entry file, as the agent pastes it, its lines kept: one or two lines,
    # worded for a reader who may not have principles installed.
    class MetaPrinciplePassage
      #: (heading: String) -> void
      def initialize(heading:)
        @heading = heading
        freeze
      end

      # The passage, ending in a line break.
      #: () -> String
      def text = "#{Prompts.markdown("set-principles-up/entry-file-passage", heading: @heading)}\n"
    end
  end
end

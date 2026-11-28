# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The parts of a candidate outline that text other than Markdown lacks: a description and an opening line, which
    # a script or a CI workflow, outlined by its comments or its jobs, never has.
    module WithoutProse
      #: () -> nil
      def description = nil

      #: () -> nil
      def cut_description = nil

      #: () -> nil
      def opening_line = nil
    end
  end
end

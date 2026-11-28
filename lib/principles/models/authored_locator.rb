# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "locator"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A new member's locator as its map stores it: its passage's opening without the indent it was quoted with, when
    # that still names one place, so its id does not keep the spaces of a YAML key or a nested list item. The given
    # opening contains the unindented one, so a lone occurrence of the unindented one is at the same place. A member
    # already mapped keeps its locator, since its id is that locator and audit records file it under that id.
    class AuthoredLocator
      #: (Project, Locator) -> void
      def initialize(project, locator)
        @project = project
        @locator = locator
        freeze
      end

      # The locator to store: the unindented one where it locates, else the one given.
      #: () -> Locator
      def stored
        unindented = @locator.with_opening_unindented or return @locator
        @project.locate_for_authoring(unindented)
        unindented
      rescue Error
        @locator
      end
    end
  end
end

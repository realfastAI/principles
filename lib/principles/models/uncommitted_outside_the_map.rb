# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The project's files outside a principle's map that differ from the audit's base commit, as an assessment
    # request names them. A project with many untracked files would put every one into each request, so
    # it names the first few and counts the rest.
    class UncommittedOutsideTheMap
      # The most paths a request names: enough to show a pattern, such as a generated folder, in a short list of
      # its own; git status lists them all.
      NAMED_AT_MOST = 10

      #: (Array[String]) -> void
      def initialize(paths)
        @paths = paths
        freeze
      end

      # The paths a request names, sorted, and how many beyond them it does not, when any.
      #: () -> Hash[String, untyped]
      def shown
        named = { "paths" => @paths.sort.first(NAMED_AT_MOST) }
        not_named = @paths.length - NAMED_AT_MOST
        not_named.positive? ? named.merge("not_named" => not_named) : named
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A plugin's install name as Claude Code records it, NAME@MARKETPLACE, which names the marketplace it came from.
    class PluginName
      #: (String) -> void
      def initialize(name)
        @name = name
        freeze
      end

      # The marketplace the plugin came from: what follows the first @, or the whole name when it has none.
      #: () -> String
      def marketplace = @name.split("@", 2).last.to_s

      #: () -> String
      def to_s = @name
    end
  end
end

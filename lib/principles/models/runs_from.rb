# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Where this run of the tool comes from, by the executable its printed commands name. The Claude Code plugin's
    # bin/principles is the one entry point that names itself bare, since its folder is on the Bash tool's PATH
    # while the plugin is enabled; a checkout or an installed gem names a Ruby and a path. Only under the
    # plugin does its session-start hook report beside CLAUDE.md.
    class RunsFrom
      # The executable the plugin's entry point names itself by.
      PLUGIN_EXECUTABLE = "principles"

      #: (String) -> void
      def initialize(executable)
        @executable = executable
        freeze
      end

      # Where this run comes from, as a fact the agent reads.
      #: () -> String
      def to_s = plugin? ? "claude_code_plugin" : "command_line"

      # Whether the plugin's session-start hook runs in the session this run is part of, which only a run from the
      # plugin shows; it says nothing of any other person's sessions.
      #: () -> bool
      def session_start_hook_in_this_session? = plugin?

      private

      #: () -> bool
      def plugin? = @executable == PLUGIN_EXECUTABLE
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A feature that runs fast standard tools in place of Ruby, on only while every tool it needs is on PATH, with
    # no Ruby fallback. TOOLS is the one central table of them, so no command checks PATH
    # itself.
    class Feature
      # The command that scans the logged requests, which a full audit's request also runs.
      LOGGED_REQUEST_SCAN = "show-members-in-logged-requests"

      # Each feature's command, and the tools it runs, each with what it does there.
      TOOLS = {
        LOGGED_REQUEST_SCAN => {
          "jq" => "decodes each captured request into its text lines",
          "rg" => "finds mapped members' lines in the decoded requests"
        }
      }.freeze #: Hash[String, Hash[String, String]]

      # The feature command runs, with on_path saying whether PATH holds a tool.
      #: (String, on_path: ^(String) -> bool) -> void
      def initialize(command, on_path:)
        @command = command
        @tools = TOOLS.fetch(command) #: Hash[String, String]
        @on_path = on_path
        freeze
      end

      # Refuses while a tool the feature runs is not on PATH, naming the first missing and what it does, so the agent
      # asks the user to install it.
      #: () -> void
      def refuse_while_off
        refusal = off_refusal
        raise refusal if refusal
      end

      # The refusal the feature gives while a tool it runs is not on PATH, or nil while it is on; for a command that
      # carries on without the feature, such as a full audit's request without its logged-request evidence.
      #: () -> Error?
      def off_refusal
        tool, does = @tools.find { |name, _| !@on_path.call(name) }
        return unless tool

        Error.new("fast_tools_missing", "#{@command} needs #{tool}, which #{does}, and #{tool} is not on PATH.",
                  "Ask the user before installing #{tool}, then run this again.")
      end
    end
  end
end

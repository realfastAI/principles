# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The install of a plugin a session in the project loads, as one of its Claude Code registry rows: the first, in
    # the host's order, that is a user install or one for the project's main checkout. A probe found the host chose so:
    # by order, not by a ranking of scopes, and in a git worktree by its main checkout's row.
    class PluginInstall
      # The row that applies to the project whose main checkout is at main_checkout, or nil when none does.
      #: (Array[Hash[String, String?]], main_checkout: String) -> PluginInstall?
      def self.applying(rows, main_checkout:)
        row = rows.find { |each| each["scope"] == "user" || each["project_path"] == main_checkout }
        new(row) if row
      end

      #: (Hash[String, String?]) -> void
      def initialize(row)
        @row = row
        freeze
      end

      # The version the host installed, which it gives for the agent's information only.
      #: () -> String?
      def version = @row["version"]

      # The folder the host installed this copy in.
      #: () -> String?
      def install_path = @row["install_path"]
    end
  end
end

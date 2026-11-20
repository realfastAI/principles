# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "frontmatter_fields"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # When Claude Code loads a project subagent's definition. Its description, which Claude reads to decide when
    # to delegate, loads at session start in the main session; its body is the subagent's own system prompt, loaded
    # in the subagent's context when Claude delegates to it. Claude Code reads .claude/agents recursively, from
    # the start folder up to the repository root, as its subagents documentation says; an experiment saw
    # a project subagent's description listed at start.
    class AgentLoads
      # An agent's definition: a Markdown file at any depth in a .claude/agents folder, at the root or below it.
      AGENT_FILE = %r{\A(?<folder>(?:.*/)?)\.claude/agents/(?:[^/]+/)*[^/]+\.md\z} #: Regexp

      # text is the agent's whole file, or nil when it cannot be read.
      #: (String, String?) -> void
      def initialize(path, text)
        @path = path
        @text = text
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h
        lines = @text&.lines or return { "when" => "not_determined" }
        return not_derived("an agents folder below the project root") unless folder.empty?

        description = FrontmatterFields.new(path: @path, lines: lines).field_lines("$.description")
        return not_derived("an agent file without a description field") unless description

        { "when" => "on_delegation", "context" => "subagent", "description" => { "when" => "session_start" } }
      rescue Error => e
        { "when" => "not_determined", "frontmatter_refused" => e.payload.fetch("code") }
      end

      # The description lines Claude reads at start to decide when to delegate, as written; nil without the field, or
      # when the file cannot be read. The subagents page states no cap on one description.
      #: () -> String?
      def description_text
        lines = @text&.lines or return nil
        FrontmatterFields.new(path: @path, lines: lines).field_lines("$.description")&.join
      rescue Error
        nil
      end

      private

      # The folder whose .claude/agents holds the agent: empty at the project root, else ending in a slash.
      #: () -> String
      def folder
        AGENT_FILE.match(@path)&.[](:folder).to_s
      end

      #: (String) -> Hash[String, untyped]
      def not_derived(why)
        { "when" => "not_determined", "not_derived" => why }
      end
    end
  end
end

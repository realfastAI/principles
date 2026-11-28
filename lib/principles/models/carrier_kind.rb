# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "agent_loads"
require_relative "hook_commands"
require_relative "plugin_reference"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The kind of harness carrier a member's file is, by its path, whose own practices a request names for judging and
    # editing it: an instruction file, a rule, a skill or a subagent, a plugin's too, a hook configuration, a script a
    # hook command names, or none when no host loads the path by itself.
    # Text a program prints into context has no kind here: the path cannot show it, so the agent judges it.
    class CarrierKind
      # The instruction files a host reads in a folder, Claude Code's and Codex's, at the root or below it.
      INSTRUCTION_FILE = %r{(?:\A|/)(?:CLAUDE\.md|\.claude/CLAUDE\.md|CLAUDE\.local\.md|AGENTS\.md)\z} #: Regexp

      # A rule file in a .claude/rules folder, at the root or below it.
      RULE_FILE = %r{(?:\A|/)\.claude/rules/.+\.md\z} #: Regexp

      # A skill's file in any skills folder: under .claude, as SkillLoads::SKILL_FILE, whose loading it derives, or at a
      # plugin's root, such as a project's own plugin folder, whose loading it does not.
      SKILL_IN_ANY_SKILLS_FOLDER = %r{(?:\A|/)skills/[^/]+/SKILL\.md\z} #: Regexp

      # A plugin member's agent file, in the agents folder at the plugin's root.
      PLUGIN_AGENT_FILE = %r{\A#{Regexp.escape(PluginReference::PREFIX)}[^/]+/agents/(?:[^/]+/)*[^/]+\.md\z} #: Regexp

      # The hooks file at a plugin's root, or a project's own plugin folder, beside the settings files hooks are read
      # from.
      HOOKS_FILE = %r{(?:\A|/)hooks/hooks\.json\z} #: Regexp

      # Each kind a path alone shows, in the order they are tried, with the paths that make a file one.
      BY_PATH = {
        "instructions" => [INSTRUCTION_FILE],
        "rule" => [RULE_FILE],
        "skill" => [SKILL_IN_ANY_SKILLS_FOLDER],
        "subagent" => [AgentLoads::AGENT_FILE, PLUGIN_AGENT_FILE],
        "hook_configuration" => [HOOKS_FILE, *HookCommands::ON_EVERY_HOST.map { /\A#{Regexp.escape(it)}\z/ }]
      }.freeze #: Hash[String, Array[Regexp]]

      # The kind of a file no host loads by itself.
      NONE = "none" #: String

      # Every kind's name: those a path shows, then a hook script and none.
      NAMES = [*BY_PATH.keys, "hook_script", NONE].freeze #: Array[String]

      # name, as an agent gives it, refused unless it is one of NAMES.
      #: (String) -> String
      def self.named(name)
        return name if NAMES.include?(name)

        raise Error.new("unknown_carrier_kind", "There is no carrier kind named #{name.inspect}.",
                        "Name one of #{ProseList.new(NAMES)}.")
      end

      # named_in_hooks is whether a hook command names the file, which makes a file no other kind holds a hook script.
      #: (String, ?named_in_hooks: bool) -> void
      def initialize(path, named_in_hooks: false)
        @path = path
        @named_in_hooks = named_in_hooks
        freeze
      end

      # The kind's name, as show-carrier-practices takes it: the first BY_PATH names, or else a hook script or none.
      #: () -> String
      def name
        by_path = BY_PATH.find { |_, paths| paths.any? { it.match?(@path) } }&.first
        by_path || (@named_in_hooks ? "hook_script" : NONE)
      end

      # Whether a host loads a file of this kind by itself, so its absence from a request is not expected.
      #: () -> bool
      def carrier? = name != NONE
    end
  end
end

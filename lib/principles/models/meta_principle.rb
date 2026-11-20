# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "activation"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The principle that keeps every other principle held, which setting principles up maps first. It is
    # this product's own principle, not an example, so what its map starts with ships with the tool; once mapped, the
    # project owns the map like any other.
    module MetaPrinciple
      ID = "sticking-to-your-principles"

      DESCRIPTION = "Every other principle stays held: each place that carries one is mapped, a change to any of " \
                    "them is judged against the rest before work goes on, and the agent loads only the guidance its " \
                    "task needs, so harness drift and debt stay visible and an agent can be trusted with longer, " \
                    "wider unsupervised work."

      # Its work is in hand in every session, since it brings the other principles back into attention.
      ACTIVATION = Activation.new({ "when" => "always" }) #: Activation

      # The heading of the passage this tool proposes, which the add-member command it prints names as the section.
      PASSAGE_HEADING = "Stick to your principles"

      # The plugin's session-start hook and skill, at the paths this product's own source keeps them. Only a project
      # holding that source can map them there; elsewhere they are in the installed plugin, outside the project. A
      # project without the plugin wires the hook into its own settings or hooks file, where Member#package_part
      # recognises it by its command; the skill comes only with the plugin.
      HOOK_PATH = "plugin/hooks/hooks.json"
      SKILL_PATH = "plugin/skills/principles/SKILL.md"

      # The part the passage plays as the principle's first member. It carries no check: a command stored in the
      # committed map runs on every machine that reads it, where principles may not be installed or may run from
      # another path.
      PASSAGE_ROLE = "States the practice of keeping every principle held, in every session"

      # The part a passage the project already has plays when it carries one of the passage's steps in its place,
      # so the step is said once.
      STEP_ROLE = "Says, for this project, one of the keeping steps"

      # The part any other place that keeps the principles held plays as a member, such as a timer or the committed
      # setting that enables the plugin: the agent replaces STEP with the keeping step it runs and TRIGGER with what
      # starts it, a hook, a timer or a reader.
      KEEPING_PLACE_ROLE = "Runs STEP, started by TRIGGER"

      # The repair line that sets this principle up, for a refusal of its id before its map exists: setup writes no
      # map, and the add-member it prints creates the map with its first member (T74).
      SET_UP = "To set it up: #{Error::EXECUTABLE} show-meta-principle-passage".freeze #: String

      # The fields this principle's map starts with as setup starts it, with no members; the add-member setup prints
      # writes the map with its first member (T74).
      #: () -> Hash[String, untyped]
      def self.starting_fields = { "description" => DESCRIPTION, "members" => [], "activation" => ACTIVATION.to_h }

      # Whether this is the built-in principle whose first member setup maps.
      #: (String) -> bool
      def self.id?(id) = id == ID

      # Setup's add-member writes this map with its first member, preserving its shipped description/activation.
      #: (String) -> void
      def self.refuse_explicit_creation(id)
        return unless id?(id)

        raise Error.new("meta_principle_id",
                        "#{id} is set up by show-meta-principle-passage, whose printed add-member creates its map " \
                        "with its first member", SET_UP)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "plugin_component"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A plugin member's path in its map, plugin://HOST/NAME@MARKETPLACE/COMPONENT: the host, the plugin's install name
    # and the file's path inside the plugin, with no version, so its id stays the same across updates, and no machine
    # path.
    class PluginReference
      # The host a plugin member's path names; Codex is not read yet.
      HOST = "claude-code" #: String

      # What every plugin member's path starts with.
      PREFIX = "plugin://#{HOST}/".freeze #: String

      # The plugin member path names, or nil when it names a project file.
      #: (String) -> PluginReference?
      def self.in(path)
        return unless path.start_with?(PREFIX)

        name, component = path.delete_prefix(PREFIX).split("/", 2)
        new(name.to_s, PluginComponent.new(component.to_s))
      end

      # The plugin's install name, NAME@MARKETPLACE.
      #: String
      attr_reader :name

      #: PluginComponent
      attr_reader :component

      #: (String, PluginComponent) -> void
      def initialize(name, component)
        @name = name
        @component = component
        freeze
      end

      #: () -> String
      def to_s = "#{PREFIX}#{@name}/#{@component.path}"

      # Where it comes from, at the version installed, as a result prints it: read-only, since the host replaces its
      # files on update.
      #: (String?) -> Hash[String, untyped]
      def source(version)
        { "host" => HOST, "plugin" => @name, "version" => version, "component" => @component.path, "read_only" => true }
      end
    end
  end
end

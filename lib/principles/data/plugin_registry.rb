# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"
require_relative "json_text"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Claude Code's record of the plugins installed on this machine, the text of installed_plugins.json under its
    # config folder: for each plugin, by its install name NAME@MARKETPLACE, one row per install, in the order the host
    # keeps them. Which row applies to a project is a model's rule; this reads the rows as the host wrote them.
    class PluginRegistry
      # The registry version this tool was written against, from a probe of Claude Code's own file.
      VERSION = 2 #: Integer

      # The registry text holds, refused when it is not a registry of the version this tool reads.
      #: (String) -> void
      def initialize(text)
        @plugins = plugins_in(parsed(text)) #: Hash[String, Array[Hash[String, untyped]]]
        freeze
      end

      # The rows for the plugin named, each with the fields a selection reads, in the host's order; none when the
      # registry names no such plugin.
      #: (String) -> Array[Hash[String, String?]]
      def rows(name)
        @plugins.fetch(name, []).map do |row|
          { "scope" => row["scope"], "version" => row["version"], "project_path" => row["projectPath"],
            "install_path" => row["installPath"] }
        end
      end

      # Every plugin install name the registry holds, sorted.
      #: () -> Array[String]
      def names = @plugins.keys.sort

      private

      #: (Hash[String, untyped]) -> Hash[String, Array[Hash[String, untyped]]]
      def plugins_in(registry)
        unless registry["version"].eql?(VERSION)
          raise Error.new("unsupported_plugin_registry",
                          "Claude Code's plugin registry is version #{registry["version"].inspect}; this tool reads " \
                          "version #{VERSION}",
                          "Map the project's own files instead; this copy cannot read this Claude Code's plugins.")
        end

        plugins = registry["plugins"]
        plugins.is_a?(Hash) && plugins.each_value.all? { |rows| rows?(rows) } ? plugins : unreadable
      end

      #: (untyped) -> bool
      def rows?(rows) = rows.is_a?(Array) ? rows.all?(Hash) : false

      #: (String) -> Hash[String, untyped]
      def parsed(text)
        registry = JsonText.new(text).parsed
        registry.is_a?(Hash) ? registry : unreadable
      rescue JSON::ParserError
        unreadable
      end

      #: () -> bot
      def unreadable
        raise Error.new("unreadable_plugin_registry",
                        "Claude Code's plugin registry is not in the shape this tool reads",
                        "Reinstall the plugin with Claude Code, or map the project's own files instead.")
      end
    end
  end
end

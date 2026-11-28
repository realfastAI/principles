# typed: strict
# frozen_string_literal: true

require_relative "bounded_file"
require_relative "plugin_registry"
require_relative "known_marketplaces"
require_relative "plugin_folder"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Claude Code's config folder on this machine, where it records the plugins it installed. This tool only reads it,
    # and never runs, installs or fetches a plugin.
    class ClaudeCodeHome
      # The folder Claude Code reads: CLAUDE_CONFIG_DIR when set, or else .claude in the home directory.
      #: (?Hash[String, String], ?home: String) -> ClaudeCodeHome
      def self.from_environment(environment = ENV.to_h, home: Dir.home)
        new(environment["CLAUDE_CONFIG_DIR"] || File.join(home, ".claude"))
      end

      #: String
      attr_reader :directory

      #: (String) -> void
      def initialize(directory)
        @directory = directory
        freeze
      end

      # The registry of installed plugins, or nil while the host has installed none.
      #: () -> PluginRegistry?
      def registry
        text = read("installed_plugins.json", "Claude Code's plugin registry")
        PluginRegistry.new(text) if text
      end

      # The marketplaces the host knows, or nil while it records none.
      #: () -> KnownMarketplaces?
      def marketplaces
        text = read("known_marketplaces.json", "Claude Code's record of its plugin marketplaces")
        KnownMarketplaces.new(text) if text
      end

      # The folder the host installed a plugin's copy in, at the path its registry gives.
      #: (String) -> PluginFolder
      def plugin_folder(path) = PluginFolder.new(path)

      private

      # The text of a file in the host's plugins folder, or nil when it is absent.
      #: (String, String) -> String?
      def read(name, named)
        path = File.join(@directory, "plugins", name)
        BoundedFile.new(path, named: named).read_text if File.exist?(path)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "digest"
require_relative "plugin_install"
require_relative "plugin_reference"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A file of an installed plugin as a session here would read it: its reference, the install it is in and its
    # text, read once.
    class InstalledComponent
      #: String
      attr_reader :text

      #: (PluginReference, PluginInstall, String) -> void
      def initialize(reference, install, text)
        @reference = reference
        @install = install
        @text = text
        freeze
      end

      # The version the host installed, for the agent's information only.
      #: () -> String?
      def version = @install.version

      # The member's path in its map, as its reference names it.
      #: () -> String
      def member_path = @reference.to_s

      # What the map pins of it: the version installed, and the hash of its text, which alone says whether it changed.
      #: () -> Hash[String, String]
      def pinned = { "version" => version.to_s, "sha256" => Digest::SHA256.hexdigest(@text) }

      # Where it comes from, as a result prints it.
      #: () -> Hash[String, untyped]
      def source = @reference.source(version)

      # Its entry in a map, playing role.
      #: (String) -> Hash[String, untyped]
      def member(role) = { "path" => member_path, "role" => role, "pinned" => pinned }

      # What add-member reports of it: its id, the lines it spans and where it comes from. No host's loading of a
      # plugin's file is derived yet.
      #: () -> Hash[String, untyped]
      def added = { "id" => member_path, **lines, "loading" => "not_derived", "source" => source }

      # The lines it spans: the whole file.
      #: () -> Hash[String, Integer]
      def lines = { "first_line" => 1, "last_line" => [@text.lines.size, 1].max }
    end
  end
end

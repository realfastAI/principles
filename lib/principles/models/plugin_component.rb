# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The file a plugin member names, by its path inside the plugin. It takes plain characters only, segments of
    # letters, digits, dots, dashes and underscores, none of them . or .., so it can only name a file under the
    # plugin's own folder and reads the same wherever it is printed. No first case needs any other character.
    class PluginComponent
      # One segment of the path: plain characters, and not . or .. alone.
      SEGMENT = /\A(?!\.{1,2}\z)[A-Za-z0-9._-]+\z/ #: Regexp

      # Whether path is plain, as a component must be.
      #: (String) -> bool
      def self.plain?(path) = !path.empty? && path.split("/", -1).all? { |segment| segment.match?(SEGMENT) }

      #: String
      attr_reader :path

      #: (String) -> void
      def initialize(path)
        unless self.class.plain?(path)
          raise Error.new("plugin_component_not_plain",
                          "#{path.inspect} is not a plain relative path inside the plugin",
                          "Name the file by its path inside the plugin, in segments of letters, digits, dots, " \
                          "dashes and underscores, with no . or .. segment.")
        end

        @path = path
        freeze
      end
    end
  end
end

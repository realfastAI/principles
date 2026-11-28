# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"
require_relative "json_text"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Claude Code's record of the marketplaces it knows, the text of known_marketplaces.json under its config folder:
    # for each marketplace by name, where its plugins come from. A probe saw a local folder recorded as source
    # "directory" without quoting how it nests, so this reads the kind either as source itself or as source.source.
    class KnownMarketplaces
      # The marketplaces text records, refused when it is not a JSON object.
      #: (String) -> void
      def initialize(text)
        @marketplaces = parsed(text) #: Hash[String, untyped]
        freeze
      end

      # The kind of source the marketplace named comes from, such as "directory" or "github", or nil when the record
      # names no such marketplace or no kind this tool can read.
      #: (String) -> String?
      def source_kind(name)
        marketplace = @marketplaces[name]
        source = marketplace["source"] if marketplace.is_a?(Hash)
        kind = source.is_a?(Hash) ? source["source"] : source
        kind if kind.is_a?(String)
      end

      private

      #: (String) -> Hash[String, untyped]
      def parsed(text)
        marketplaces = JsonText.new(text).parsed
        marketplaces.is_a?(Hash) ? marketplaces : unreadable
      rescue JSON::ParserError
        unreadable
      end

      #: () -> bot
      def unreadable
        raise Error.new("unreadable_plugin_registry",
                        "Claude Code's record of its plugin marketplaces is not in the shape this tool reads",
                        "Reinstall the plugin with Claude Code, or map the project's own files instead.")
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "json"
require_relative "project_history"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One member key's ordered historical placements and its oldest locatable mapping baseline.
    class MemberMappingRun
      #: (String, Array[[String, Hash[String, untyped]]]) -> void
      def initialize(key, entries)
        @key = key.dup.freeze #: String
        @entries = JSON.parse(JSON.generate(entries), freeze: true) #: Array[[String, Hash[String, untyped]]]
        freeze
      end

      #: (ProjectHistory) -> Hash[String, String]?
      def baseline(history)
        @entries.reverse_each do |sha, fields|
          hash = history.hashes_by_key_at(sha, [fields])[@key] or next

          return { "commit" => sha, "sha256" => hash }
        end
        nil
      end
    end
  end
end

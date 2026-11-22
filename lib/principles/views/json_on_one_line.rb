# typed: strict
# frozen_string_literal: true

require "json"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # An object that prints compact on one line inside a result printed a field a line, and reads as the hash it holds
    # everywhere else. An answer guide's example is one: the agent copies it whole into its answer, and printed a field
    # a line and unindented it ran several levels deep, where a key after closing brackets could not be placed.
    class JsonOnOneLine < Hash
      # The object compact, whatever layout the result around it prints in.
      #: (*untyped) -> String
      def to_json(*) = JSON.generate(to_h)
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "printed_json"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A JSON result printed a field a line, as every result prints, but for one array whose entries each print compact
    # on a line of their own. list-candidate-files' file entries are that array: a field a line costs a third more
    # lines than an entry a line, and one compact line of 27 KB is the worst shape to read by lines.
    class JsonWithEntriesOnLines
      # The array is result[under][key].
      #: (Hash[String, untyped], under: String, key: String) -> void
      def initialize(result, under:, key:)
        @result = result
        @path = [under, key] #: Array[String]
        freeze
      end

      # The result as JSON generates it, so a reader of the values need not know the layout.
      #: (?untyped, *untyped) -> String
      def to_json(state = nil, *) = @result.to_json(state)

      # The result as printed.
      #: () -> String
      def text = PrintedJson.with_entries_on_lines(@result, @path)
    end
  end
end

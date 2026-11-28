# typed: strict
# frozen_string_literal: true

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # One line of a captured request's string that holds a pattern, as the scan keeps it: the request, the JSON path
    # of the string, its segment, the line's text, and the byte in the string the line starts at. A plain class, not
    # ::Data.define, since Sorbet's strict level needs a signature for each reader, which ::Data.define's lack.
    class KeptLine
      #: (String, String, String, String, Integer) -> void
      def initialize(request, path, segment, text, offset)
        @request = request
        @path = path
        @segment = segment
        @text = text
        @offset = offset
        freeze
      end

      #: String
      attr_reader :request, :path, :segment, :text

      #: Integer
      attr_reader :offset

      # The place it was kept in, a request, path and segment, which a member's lines are counted by.
      #: () -> [String, String, String]
      def place = [@request, @path, @segment]
    end
  end
end

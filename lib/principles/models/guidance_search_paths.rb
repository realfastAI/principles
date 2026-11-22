# typed: strict
# frozen_string_literal: true

require_relative "../data/guidance_search_paths_file"
require_relative "guidance_search_path"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The additional guidance globs this project records, with one owner for normalized additions and removals.
    class GuidanceSearchPaths
      #: Array[String]
      attr_reader :globs

      #: (Data::GuidanceSearchPathsFile) -> GuidanceSearchPaths
      def self.read(file) = new(file.read, file)

      #: (Hash[String, untyped], Data::GuidanceSearchPathsFile) -> void
      def initialize(fields, file)
        @file = file
        normalized = fields.fetch("globs").map { |glob| GuidanceSearchPath.new(glob).glob }
        @globs = normalized.uniq.sort.freeze #: Array[String]
        freeze
      end

      #: (String) -> GuidanceSearchPaths
      def adding(glob) = with(@globs | [GuidanceSearchPath.new(glob).glob])

      #: (String) -> GuidanceSearchPaths
      def removing(glob)
        normalized = GuidanceSearchPath.new(glob).glob
        unless @globs.include?(normalized)
          raise Error.new("unknown_guidance_search_path",
                          "#{normalized.inspect} is not a recorded guidance search path",
                          "Remove an exact glob listed in recorded_guidance_search_paths.", @file.relative)
                     .including("recorded_guidance_search_paths" => @globs)
        end

        with(@globs - [normalized])
      end

      #: (GuidanceSearchPaths) -> bool
      def same_as?(other) = @globs == other.globs

      # The glob this list records that other did not, which a survey of just its matches reads; nil when none is.
      #: (GuidanceSearchPaths) -> String?
      def added_since(other) = (@globs - other.globs).first

      #: () -> String
      def save
        @file.write("format" => Data::GuidanceSearchPathsFile::FORMAT, "globs" => @globs)
        @file.relative
      end

      private

      #: (Array[String]) -> GuidanceSearchPaths
      def with(globs) = GuidanceSearchPaths.new({ "globs" => globs }, @file)
    end
  end
end

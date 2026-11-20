# typed: strict
# frozen_string_literal: true

require_relative "guidance_search_path"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The project's recorded guidance search paths and this invocation's temporary selections, combined once.
    class SurveySearchPaths
      #: Array[String]
      attr_reader :globs

      #: (recorded: Array[String], also: Array[String]) -> void
      def initialize(recorded:, also:)
        @recorded = recorded.map { |glob| GuidanceSearchPath.new(glob).glob }.uniq.freeze #: Array[String]
        @globs = (@recorded | also.map { |glob| GuidanceSearchPath.new(glob).glob }).freeze #: Array[String]
        freeze
      end

      # Saved provenance is distinct from all match counts; omit it when the project records no search paths.
      #: () -> Hash[String, untyped]
      def recorded_listing = @recorded.empty? ? {} : { "recorded_guidance_search_paths" => @recorded }
    end
  end
end

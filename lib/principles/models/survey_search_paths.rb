# typed: strict
# frozen_string_literal: true

require_relative "guidance_search_path"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The project's recorded guidance search paths and this invocation's temporary selections, combined once.
    # Selections made with only replace both the recorded paths and the places hosts load by convention, so a
    # survey after a search path is added reads just the files it matches.
    class SurveySearchPaths
      #: Array[String]
      attr_reader :globs

      #: (recorded: Array[String], also: Array[String], ?only: Array[String]) -> void
      def initialize(recorded:, also:, only: [])
        @conventional = only.empty? #: bool
        kept = @conventional ? recorded : [] #: Array[String]
        @recorded = kept.map { |glob| GuidanceSearchPath.new(glob).glob }.uniq.freeze #: Array[String]
        @globs = (@recorded | (also + only).map { |glob| GuidanceSearchPath.new(glob).glob }).freeze #: Array[String]
        freeze
      end

      # Whether the survey lists the places hosts load by convention as well as these globs' matches.
      #: () -> bool
      def conventional? = @conventional

      # Saved provenance is distinct from all match counts; omit it when the project records no search paths.
      #: () -> Hash[String, untyped]
      def recorded_listing = @recorded.empty? ? {} : { "recorded_guidance_search_paths" => @recorded }
    end
  end
end

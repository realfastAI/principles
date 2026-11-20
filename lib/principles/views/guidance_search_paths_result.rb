# typed: strict
# frozen_string_literal: true

require_relative "invocation"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The recorded list and an immediate read-only survey after a guidance-search-path write.
    class GuidanceSearchPathsResult
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      #: (status: String, globs: Array[String], wrote: Array[String]) -> Hash[String, untyped]
      def result(status:, globs:, wrote:)
        survey = @invocation.in_project("list-candidate-files")
        { "status" => status, "recorded_guidance_search_paths" => globs, "wrote" => wrote,
          "next_action" => "Commit changed configuration.\n" \
                           "Survey again using the saved search paths: #{survey}" }
      end
    end
  end
end

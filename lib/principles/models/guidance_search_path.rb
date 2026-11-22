# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A glob the agent names for additional guidance inside this project, never a path outside it.
    class GuidanceSearchPath
      #: String
      attr_reader :glob

      #: (String) -> void
      def initialize(glob)
        @glob = glob.sub(%r{\A(?:\./)+}, "").freeze #: String
        if @glob.strip.empty? || @glob.start_with?("/") || @glob.include?("\u0000") || @glob.split("/").include?("..")
          raise Error.new("invalid_guidance_search_path", "Guidance search paths must stay inside this project",
                          "Give a quoted root-relative glob, such as 'guides/**/*.md', with no parent segments.", glob)
        end

        freeze
      end
    end
  end
end

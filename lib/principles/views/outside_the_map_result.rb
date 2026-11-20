# typed: strict
# frozen_string_literal: true

require_relative "prompts"
require_relative "request_part"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How a full audit's request names the files outside the map that differ from the base commit, which a check and
    # the answer's evidence read as they are now.
    class OutsideTheMapResult
      # The part this lists, by the name the request prints it under and start-audit --part takes.
      PART = "uncommitted_files_outside_the_map" #: String

      # outside names the files outside, as paths and any count not_named; nil when there are none or no base commit.
      #: (Hash[String, untyped]?) -> void
      def initialize(outside)
        @outside = outside
        freeze
      end

      # The request's part naming the files outside, with why they matter to the answer; nil when there are none,
      # and then nothing is printed.
      #: () -> RequestPart?
      def part
        outside = @outside or return

        why = Prompts.text("assess-every-member/uncommitted-files-outside-the-map")
        RequestPart.new(shown: { PART => outside.merge("why" => why) }, slots: {})
      end
    end
  end
end

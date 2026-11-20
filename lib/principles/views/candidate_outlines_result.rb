# typed: strict
# frozen_string_literal: true

require_relative "prompts"
require_relative "json_with_entries_on_lines"

module Principles
  module Views
    # The requested outlines, with the same omissions as a survey and the way to request less at once.
    class CandidateOutlinesResult
      #: (Hash[String, untyped]) -> void
      def initialize(inventory)
        @inventory = inventory
        freeze
      end

      #: () -> JsonWithEntriesOnLines
      def result
        values = { "status" => "ok", "question" => Prompts.text("read-requested-outlines/continue-the-survey"),
                   "inventory" => @inventory, "wrote" => [] }
        JsonWithEntriesOnLines.new(values, under: "inventory", key: "files")
      end
    end
  end
end

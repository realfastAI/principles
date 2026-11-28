# typed: strict
# frozen_string_literal: true

module Principles
  module Views
    # The other maps holding a new whole-file member's file whole, which ask the agent AddedMember's scope-or-join
    # question.
    class WholeFileElsewhere
      #: (?Array[String]) -> void
      def initialize(principle_ids = [])
        @principle_ids = principle_ids
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h = @principle_ids.empty? ? {} : { "whole_file_elsewhere" => @principle_ids }

      #: () -> String
      def note
        return "" if @principle_ids.empty?

        "Other principles hold this whole file too (whole_file_elsewhere), so every edit to it is a change to each. "
      end

      # Whether it asks AddedMember's scope-or-join question: when other principles hold the file whole.
      #: () -> bool
      def asks_scope_or_join? = @principle_ids.any?
    end
  end
end

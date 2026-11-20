# typed: strict
# frozen_string_literal: true

module Principles
  module Views
    # A new known scope's literal facts and the availability question, from plain values only.
    class NewLoadingScope
      UNKNOWN_LIMIT = "Unknown scopes in not_compared remain limitations. "

      #: (?Hash[String, untyped]) -> void
      def initialize(facts = {})
        @facts = facts
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h = @facts.empty? ? {} : { "new_loading_scope" => @facts }

      #: () -> String
      def note
        return "" if @facts.empty?

        "Claude Code loading derivation, assuming a session at the project root, gives this member a known " \
          "scope not already represented (new_loading_scope). Will each carrier be available where this principle " \
          "applies, or should one link to another carrier? These are predictions, not observed delivery; " \
          "literal paths do not establish glob coverage. " \
          "#{UNKNOWN_LIMIT if @facts.fetch("not_compared", []).any?}"
      end
    end
  end
end

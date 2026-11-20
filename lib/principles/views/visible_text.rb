# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # Text from a project file or an agent's answer, printed outside JSON with each control, format and separator
    # character written as \uXXXX, as JSON output shows it, so a tab cannot split a field and an invisible character
    # cannot hide. cli.rb escapes printed JSON without control characters, since JSON already escapes them
    # inside strings and its own newlines must stay; so the two are not one rule to fold together.
    class VisibleText
      #: (String) -> void
      def initialize(text)
        @text = text
        freeze
      end

      #: () -> String
      def to_s
        @text.gsub(/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/) do |character|
          character.encode("UTF-16BE").unpack("n*").map { |unit| format("\\u%04x", unit) }.join
        end
      end
    end
  end
end

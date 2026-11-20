# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One word of a printed command, as a shell reads it: as it is when it holds only characters no shell treats
    # specially, else in single quotes, inside which a shell expands nothing. Ids, paths and headings come from
    # project files anyone may have written.
    class ShellWord
      # A word every common shell reads as it is: no quote, space, $, `, glob or redirection, and no = or #,
      # which zsh can expand.
      PLAIN = %r{\A[\w./:@%+,-]+\z}

      #: (String) -> void
      def initialize(value)
        @value = value
        freeze
      end

      #: () -> String
      def to_s
        return @value if PLAIN.match?(@value)

        "'#{@value.gsub("'") { "'\\''" }}'"
      end
    end
  end
end

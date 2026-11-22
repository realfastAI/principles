# typed: strict
# frozen_string_literal: true

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The json parser's message about text it could not parse, with the rest of the input it quotes from where it
    # stopped cut to an excerpt, since a raw line break early in a long answer echoed the whole rest of the file.
    # json 2.9.1, Ruby 3.4's own, quotes that rest with no line or column; later versions give both after it. A
    # message quoting none of the input is kept as it is.
    class ParserMessage
      # The characters of the rest of the input the message keeps.
      EXCERPT = 60 #: Integer

      # How each json version's message ends just before the rest of the input it quotes: json 2.9.1's
      # "unexpected token at '", and a later version's reason and colon. A message ending as the input does but
      # after neither quotes none of it.
      LEADS = ["at '", ": "].freeze #: Array[String]

      # Where a later json says it stopped, after the rest of the input.
      POSITION = / at line \d+ column \d+\z/ #: Regexp

      #: (String, String) -> void
      def initialize(text, message)
        @text = text
        @message = message
        freeze
      end

      #: () -> String
      def to_s
        position = @message[POSITION].to_s
        quoted = @message.delete_suffix(position)
        quoted = quoted.delete_suffix("'") if quoted.end_with?("'") && !@text.end_with?("'")
        rest = common_suffix(quoted)
        lead = quoted.delete_suffix(rest)
        return @message if rest.empty? || LEADS.none? { lead.end_with?(it) }

        "#{lead.delete_suffix("'")}#{excerpt(rest)}#{position}"
      end

      private

      # The longest end that quoted shares with the text: the rest of the input it quotes.
      #: (String) -> String
      def common_suffix(quoted)
        length = 0
        length += 1 while length < quoted.length && length < @text.length && quoted[-1 - length] == @text[-1 - length]
        quoted[quoted.length - length, length].to_s
      end

      # rest's first characters, written so a line break or control character shows, and how many bytes follow.
      #: (String) -> String
      def excerpt(rest)
        kept = rest[0, EXCERPT].to_s
        left = rest.bytesize - kept.bytesize
        left.positive? ? "#{kept.inspect} and #{left} more bytes" : kept.inspect
      end
    end
  end
end

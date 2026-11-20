# typed: strict
# frozen_string_literal: true

require "strscan"
require_relative "../error"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # One quoted name or string in a JSONPath query, read as RFC 9535 writes it: single or double quotes, the
    # escapes it defines, and no raw control character. Anything else refuses the whole query.
    class JsonPathString
      # The escapes a quoted name or string may hold, and what each stands for.
      ESCAPES = { "b" => "\b", "f" => "\f", "n" => "\n", "r" => "\r", "t" => "\t", "/" => "/", "\\" => "\\",
                  "'" => "'", "\"" => "\"" }.freeze #: Hash[String, String]

      # query is the whole query, which a refusal names.
      #: (String) -> void
      def initialize(query)
        @query = query
        freeze
      end

      # The string that starts at scanner, its quotes and escapes read; scanner is left after its closing quote.
      #: (StringScanner) -> String
      def read(scanner)
        string(scanner)
      end

      private

      # A quoted string, single or double, with its escapes read.
      #: (StringScanner) -> String
      def string(scanner)
        quote = scanner.getch.to_s
        text = +""
        until scanner.scan(quote)
          refuse("a quoted string is not closed") if scanner.eos?
          text << (scanner.scan("\\") ? escaped(scanner, quote) : unescaped(scanner))
        end
        text
      end

      # One escape after a backslash. A quote may be escaped only inside quotes of its own kind, and a \u escape
      # naming half of a surrogate pair is outside the profile.
      #: (StringScanner, String) -> String
      def escaped(scanner, quote)
        if scanner.scan(/u\h{4}/)
          point = scanner.matched.to_s[1, 4].to_s.hex
          refuse("a \\u escape for a surrogate is outside the profile") if point.between?(0xD800, 0xDFFF)
          return [point].pack("U")
        end
        char = scanner.getch.to_s
        other_quote = quote == "'" ? '"' : "'"
        refuse("a string holds an escape JSONPath does not define") if char == other_quote

        ESCAPES.fetch(char) { refuse("a string holds an escape JSONPath does not define") }
      end

      # One character as written; a control character must be escaped.
      #: (StringScanner) -> String
      def unescaped(scanner)
        char = scanner.getch.to_s
        refuse("a string holds an unescaped control character") if char.ord < 0x20

        char
      end

      #: (String) -> bot
      def refuse(why)
        raise Error.new("unsupported_query", "#{@query.inspect} is outside the supported JSONPath profile: #{why}",
                        "Quote names with ' or \", escaping only what RFC 9535 defines.")
      end
    end
  end
end

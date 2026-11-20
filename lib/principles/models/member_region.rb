# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "member_file"
require_relative "line_span"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # A file-selected region's text and full-file character origin, for literal passage matching.
    class MemberRegion
      # How many ambiguous passage openings the refusal names, so one character cannot list the whole file.
      OPENINGS_NAMED = 5 #: Integer
      ENDINGS_NAMED = 5 #: Integer

      #: (MemberFile, span: LineSpan) -> void
      def initialize(file, span:)
        @path = file.path.dup.freeze #: String
        @text = file.text.dup.freeze #: String
        region = captured_region(span)
        @before = region[0] #: Integer
        @selected = region[1] #: String
        freeze
      end

      # Existing references use one opening and the first eligible ending, or the opening's whole line.
      #: (String, String?) -> [Integer, Integer, String]
      def passage(start_text, end_text)
        start = only_opening(@selected, start_text, @before)
        found = @selected[start...passage_end(@selected, start, start_text, end_text)].to_s
        line = @text[0, @before + start].to_s.count("\n")
        [line, line + line_count(found), found]
      end

      # The narrower constraint applied only before persisting a newly authored locator.
      #: (String, String) -> void
      def check_authored_ending(start_text, end_text)
        start = only_opening(@selected, start_text, @before)
        offsets = ending_offsets(start + start_text.length, end_text)
        ambiguous_ending(end_text, offsets) if offsets.length > 1
      end

      private

      # Every eligible literal start counts, including endings that overlap a previous ending.
      #: (Integer, String) -> Array[Integer]
      def ending_offsets(after, ending)
        offsets = [] #: Array[Integer]
        while (found = @selected.index(ending, after))
          offsets << (@before + found)
          after = found + 1
        end
        offsets
      end

      #: (String, Array[Integer]) -> bot
      def ambiguous_ending(ending, offsets)
        candidates = offsets.first(ENDINGS_NAMED).map { ending_candidate(it) }
        raise Error.new("ambiguous_passage_end", "#{ending.inspect} has #{offsets.length} eligible endings",
                        "Give a more specific --ending-at closing quote that occurs once after the complete opening.",
                        @path).including("eligible_ending_count" => offsets.length, "ending_candidates" => candidates,
                                         "ending_candidates_omitted" => offsets.length - candidates.length)
      end

      # Coordinates use characters, consistently with String#index and the complete-opening boundary.
      #: (Integer) -> Hash[String, Integer]
      def ending_candidate(offset)
        prefix = @text[0, offset].to_s
        { "line" => prefix.count("\n") + 1, "column" => offset - (prefix.rindex("\n") || -1) }
      end

      # Selected text and its character origin from the file-type's inclusive line span.
      #: (LineSpan) -> [Integer, String]
      def captured_region(span)
        lines = @text.lines
        first = span.first_line - 1
        [lines[0...first].to_a.join.length, lines[first...span.last_line].to_a.join.freeze]
      end

      #: (String) -> Integer
      def line_count(found)
        found.count("\n") + (found.end_with?("\n") ? 0 : 1)
      end

      #: (String, String, Integer) -> Integer
      def only_opening(text, start_text, before)
        starts = text.enum_for(:scan, start_text).filter_map { Regexp.last_match&.begin(0) }
        return starts.first.to_i if starts.length == 1

        starts.empty? ? opening_not_found(start_text) : ambiguous_opening(start_text, starts.map { before + it })
      end

      #: (String) -> bot
      def opening_not_found(start_text)
        raise Error.new("passage_not_found", "The passage starting #{start_text.inspect} is not in the file",
                        "Quote the passage's opening text exactly.", @path)
      end

      #: (String, Array[Integer]) -> bot
      def ambiguous_opening(start_text, offsets)
        raise Error.new("ambiguous_passage",
                        "#{start_text.inspect} occurs #{offsets.length} times, at lines #{lines_named(offsets)}",
                        "Quote more of the passage's start so it occurs once.", @path)
      end

      #: (Array[Integer]) -> String
      def lines_named(offsets)
        named = offsets.first(OPENINGS_NAMED).map { (@text[0, it].to_s.count("\n") + 1).to_s }
        more = offsets.length - named.length
        more.zero? ? ProseList.new(named).to_s : "#{named.join(", ")} and #{more} more"
      end

      #: (String, Integer, String, String?) -> Integer
      def passage_end(text, start, start_text, end_text)
        return (text.index("\n", start) || (text.length - 1)) + 1 unless end_text

        found = text.index(end_text, start + start_text.length)
        unless found
          raise Error.new("passage_end_not_found", "No #{end_text.inspect} after #{start_text.inspect}",
                          "Quote the passage's closing text exactly.", @path)
        end

        found + end_text.length
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"
require_relative "decoded_leaf"
require_relative "kept_line"
require_relative "raw_request_filter"
require_relative "string_counts"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # What a scan found in the captured requests. RawRequestFilter picks the request files that may hold a pattern,
    # StringCounts counts the strings of the others, and only the picked ones are decoded: one jq run writes each
    # string in them as one line, request<TAB>path<TAB>string, the path and string as JSON, and one rg run keeps those
    # holding a pattern, escaped by the same jq, as fixed strings. Each distinct kept string is then split into its
    # lines once. It holds each line holding a pattern as a KeptLine, how many strings each request it read through
    # held, by request, and whether the scan was whole.
    class LoggedRequestMatches
      # Each string in a request, prefixed by the request file and its JSON path, both written as JSON, so no string
      # can stop the run or split a line. After a request's strings comes its end line, request<TAB><TAB>strings,
      # giving how many it held; only an end line has an empty path, so a request with none was not decoded to its
      # end.
      DECODE = <<~JQ
        (input_filename | split("/") | last) as $request
        | [paths(type == "string")] as $paths
        | ($paths[] as $path | [$request, ($path | tojson), (getpath($path) | tojson)] | join("\\t")),
          ([$request, "", ($paths | length | tostring)] | join("\\t"))
      JQ
      # The fixed string rg keeps each end line by: no other line holds two tabs together.
      ENDING = "\t\t"
      # Each pattern line as jq writes it inside a JSON string, so a pattern finds the strings DECODE wrote.
      ESCAPE = "tojson | .[1:-1]"

      # Runs jq and rg over files in the requests folder, keeping each line holding one of patterns, none of them
      # empty.
      #: (String, Array[String], Array[String]) -> LoggedRequestMatches
      def self.run(requests, files, patterns)
        listed, listing = RawRequestFilter.listing(requests, files, patterns)
        counts, counting = StringCounts.of(requests, files - listed)
        decoded = listed.empty? ? new(found: [], leaves: {}, whole: true) : decoded(requests, listed, patterns)
        new(found: decoded.found, leaves: { **counts, **decoded.leaves }, whole: listing && counting && decoded.whole)
      end

      # One jq and rg run over files, keeping each line holding one of patterns.
      #: (String, Array[String], Array[String]) -> LoggedRequestMatches
      def self.decoded(requests, files, patterns)
        written, escaping = escaped(patterns)
        Tempfile.create("principles-patterns") do |listed|
          listed.write([*written, ENDING].join("\n"))
          listed.flush
          Tempfile.create("principles-decode-errors") do |errors|
            kept, statuses = decode_and_match(requests, files, listed.path, errors.path)
            kept_lines(kept, patterns, escaping && whole?(statuses, errors.path))
          end
        end
      end

      # patterns as ESCAPE writes them, one a line, and whether jq wrote each of them and no error: a pattern it did
      # not write finds nothing, so the run is not whole without it. capture3 reads while it writes, so many patterns
      # cannot fill the pipes and stall, and it keeps jq's errors off this tool's output.
      #: (Array[String]) -> [Array[String], bool]
      def self.escaped(patterns)
        written, errors, status = Open3.capture3("jq", "-rR", ESCAPE, stdin_data: patterns.join("\n"))
        lines = written.split("\n")
        [lines, status.success? == true && errors.empty? && lines.size == patterns.size]
      end

      # Each line rg kept, and both processes' exit statuses, their errors going to errors_path.
      #: (String, Array[String], String, String) -> [Array[String], Array[Process::Status]]
      def self.decode_and_match(requests, files, patterns_file, errors_path)
        kept = [] #: Array[String]
        statuses = [] #: Array[Process::Status]
        Open3.pipeline_r(["jq", "-r", DECODE, *files], ["rg", "--no-config", "-F", "-f", patterns_file, "-"],
                         chdir: requests, err: errors_path) do |output, waits|
          kept = output.each_line(chomp: true).to_a
          statuses = waits.map(&:value)
        end
        [kept, statuses]
      end

      # Whether jq ran through every file, which its exit status alone does not say, as it names only the last file's
      # error, so any error either process wrote counts too; and rg read all jq gave it, finding a line or none. The
      # errors' words are never kept, since jq's can quote a value from a request.
      #: (Array[Process::Status], String) -> bool
      def self.whole?(statuses, errors_path)
        case statuses.map(&:exitstatus)
        in [0, 0 | 1] then File.empty?(errors_path)
        else false
        end
      end

      # The lines rg kept: the end lines count each request's strings, and each other names a string holding a pattern.
      #: (Array[String], Array[String], bool) -> LoggedRequestMatches
      def self.kept_lines(kept, patterns, whole)
        endings, strings = kept.map { it.split("\t", 3).map(&:to_s) }.partition { |_, path, _| path.to_s.empty? }
        leaves = endings.to_h { |request, _, count| [request.to_s, Integer(count)] }
        new(found: lines_holding(strings, patterns), leaves:, whole:)
      end

      # Each line of strings, each as [request, path, string] in JSON, holding one of patterns, as [request, path,
      # segment, line, offset], offset the byte in the string it starts at, each distinct string read once.
      #: (Array[Array[String]], Array[String]) -> Array[KeptLine]
      def self.lines_holding(strings, patterns)
        held = strings.map(&:last).uniq.to_h { [it, DecodedLeaf.new(JSON.parse(it.to_s)).holding(patterns)] }
        strings.flat_map { |request, path, leaf| kept_in(request.to_s, path.to_s, held.fetch(leaf)) }
      end

      # Each of lines, as DecodedLeaf#holding gives them, kept in request at path, the path in JSON.
      #: (String, String, Array[[String, String, Integer]]) -> Array[KeptLine]
      def self.kept_in(request, path, lines)
        place = JSON.parse(path).join(".")
        lines.map { |segment, line, at| KeptLine.new(request, place, segment, line, at) }
      end
      private_class_method :decoded, :escaped, :decode_and_match, :whole?, :kept_lines, :lines_holding, :kept_in

      #: Array[KeptLine]
      attr_reader :found
      #: Hash[String, Integer]
      attr_reader :leaves

      # Whether the run read every file through: jq exited 0, neither process wrote an error, and rg read all it was
      # given.
      #: bool
      attr_reader :whole

      #: (found: Array[KeptLine], leaves: Hash[String, Integer], whole: bool) -> void
      def initialize(found:, leaves:, whole:)
        @found = found
        @leaves = leaves
        @whole = whole
        freeze
      end
    end
  end
end

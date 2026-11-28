# typed: strict
# frozen_string_literal: true

require "json"
require_relative "logged_request_matches"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The requests the host captured in a request-logging folder, scanned by fast standard tools rather than Ruby:
    # LoggedRequestMatches runs the jq and rg that decode and match them. A segment is reminder inside a
    # system-reminder tag and plain outside one. jq and rg must be on PATH; Models::Feature refuses before a scan
    # runs without them.
    class LoggedRequestScan
      REQUEST = "*.request.json"
      INDEX = "index.jsonl"

      # Each tool a request lists with defer_loading, as request<TAB>path: the host sends such a tool by name, and its
      # definition reaches the model only once a tool search loads it.
      DEFERRED = <<~'JQ'
        (input_filename | split("/") | last) as $request
        | (.tools // []) | to_entries[] | select(.value.defer_loading == true)
        | "\($request)\ttools.\(.key)"
      JQ

      # DEFERRED, printing nothing, so a file it stops at fails it. It stands for both programs the other reads run:
      # LoggedRequestMatches::DECODE reads any whole JSON through, so a file it stops at DEFERRED stops at too, and
      # probing with it alone spares decoding every string of every request twice.
      PROBE = "(#{DEFERRED}) | empty".freeze #: String

      # Reads which request files the scan can read through once, here, so every read of this scan leaves the same ones
      # out. That runs jq as the scan is built, which is fine as a command builds one scan per run.
      #: (String) -> void
      def initialize(requests)
        @requests = requests
        @unreadable = unreadable_files.freeze #: Array[Hash[String, String]]
        freeze
      end

      # Each request file, by name, with the query_source its index line gives, or nil when the response failed and
      # the host wrote it none.
      #: () -> Array[Hash[String, String?]]
      def requests
        sources = index_sources
        request_files.map { |name| { "file" => name, "query_source" => sources[name] } }
      end

      # Each decoded line holding one of patterns, and each request's count of strings. Each pattern is one line; an
      # empty one is left out, since rg would match every line by it.
      #: (Array[String]) -> LoggedRequestMatches
      def matches(patterns)
        patterns = patterns.reject(&:empty?)
        files = readable_files
        return LoggedRequestMatches.new(found: [], leaves: {}, whole: true) if files.empty? || patterns.empty?

        LoggedRequestMatches.run(@requests, files, patterns)
      end

      # Each request file the scan cannot read through, by its request and its reason: not_whole_json for one that is
      # not whole JSON, such as one a host left truncated, and not_decoded for whole JSON a read stops at, such as a
      # list. jq stops at such a file, so the other reads leave these out rather than read it in part.
      #: Array[Hash[String, String]]
      attr_reader :unreadable

      # Each tool a request defers loading, as [request, path].
      #: () -> Array[[String, String]]
      def deferred_tools
        files = readable_files
        return [] if files.empty?

        listed = IO.popen(["jq", "-r", DEFERRED, *files], chdir: @requests, &:read)
        listed.to_s.lines.map do |line|
          request, path = line.chomp.split("\t", 2)
          [request.to_s, path.to_s]
        end
      end

      private

      #: () -> Array[String]
      def request_files = Dir.exist?(@requests) ? Dir.glob(REQUEST, base: @requests).sort : []

      # One jq run probes every request file, and each is probed alone only when that run fails. The reason is a fixed
      # code, never jq's message, which can quote a value from the request.
      #: () -> Array[Hash[String, String]]
      def unreadable_files
        files = request_files
        return [] if files.empty? || runs?(PROBE, files)

        files.reject { runs?(PROBE, [it]) }
             .map { { "request" => it, "reason" => runs?("empty", [it]) ? "not_decoded" : "not_whole_json" } }
      end

      #: () -> Array[String]
      def readable_files = request_files - @unreadable.map { it.fetch("request") }

      # Whether jq runs program, which prints nothing, through every one of files. jq's exit status tells only whether
      # the last file failed, so an error it printed for any other file fails it too; its words are never kept.
      #: (String, Array[String]) -> bool
      def runs?(program, files)
        printed = IO.popen(["jq", program, *files], chdir: @requests, err: %i[child out], &:read)
        Process.last_status&.success? == true && printed.to_s.empty?
      end

      # The query_source of each request the index names, by its file name.
      #: () -> Hash[String, String?]
      def index_sources
        index = File.join(@requests, INDEX)
        return {} unless File.file?(index)

        File.foreach(index).filter_map do |line|
          entry = JSON.parse(line)
          [File.basename(entry.fetch("request_file")), entry["query_source"]] if entry.is_a?(Hash)
        rescue JSON::ParserError, KeyError, TypeError
          nil
        end.to_h
      end
    end
  end
end

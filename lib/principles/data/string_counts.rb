# typed: strict
# frozen_string_literal: true

require "tempfile"
require_relative "ran"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # How many strings each of some request files holds, counted by one jq run without decoding them, for the requests
    # the raw filter leaves undecoded, so the scan still says how much it read.
    module StringCounts
      # Each request with its count, as request<TAB>count.
      COUNT = '"\(input_filename | split("/") | last)\t\([.. | strings] | length)"'

      # Each of files, in the requests folder, with its count of strings, and whether jq read every file through and
      # wrote no error, whose words are never kept, since they can quote a value from a request.
      #: (String, Array[String]) -> [Hash[String, Integer], bool]
      def self.of(requests, files)
        return [{}, true] if files.empty?

        Tempfile.create("principles-count-errors") do |errors|
          printed, status = Ran.run(["jq", "-r", COUNT, *files], requests, errors.path)
          [counted(printed), [0].include?(status) && File.empty?(errors.path)]
        end
      end

      # Each request jq printed, with its count.
      #: (String) -> Hash[String, Integer]
      def self.counted(printed)
        printed.split("\n").to_h do |line|
          request, count = line.split("\t", 2)
          [request.to_s, Integer(count)]
        end
      end
      private_class_method :counted
    end
  end
end

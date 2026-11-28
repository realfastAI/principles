# typed: strict
# frozen_string_literal: true

require_relative "../data/logged_request_scan"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # How much of the captured requests one scan read: how many there were, how many strings it decoded, and whether
    # it read every one through. A member reported absent is proven absent only when it did, so each request it did
    # not decode to its end is named, beside those it could not read at all.
    class LoggedRequestScanCompleteness
      # What scan read in its run matched.
      #: (Data::LoggedRequestScan, Data::LoggedRequestMatches) -> LoggedRequestScanCompleteness
      def self.of(scan, matched)
        new(requests: scan.requests.map { it.fetch("file").to_s }, unreadable: scan.unreadable, matched:)
      end

      #: (requests: Array[String], unreadable: Array[Hash[String, String]],
      #|  matched: Data::LoggedRequestMatches) -> void
      def initialize(requests:, unreadable:, matched:)
        @requests = requests
        @matched = matched
        undecoded = requests - unreadable.map { it.fetch("request") } - matched.leaves.keys
        named = undecoded.map { { "request" => it, "reason" => "not_decoded" } }
        @unreadable = [*unreadable, *named].freeze #: Array[Hash[String, String]]
        freeze
      end

      # Each request the scan could not read through, by its request and reason.
      #: Array[Hash[String, String]]
      attr_reader :unreadable

      # The requests captured, those it could not read too, the strings decoded in them, and whether the scan read
      # every one through.
      #: () -> Hash[String, untyped]
      def to_h
        { "captured" => @requests.size, "leaves" => @matched.leaves.values.sum,
          "complete" => @unreadable.empty? && @matched.whole }
      end
    end
  end
end

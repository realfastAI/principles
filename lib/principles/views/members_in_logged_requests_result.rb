# typed: strict
# frozen_string_literal: true

require_relative "logged_request_status_meanings"
require_relative "problem_lines"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How many mapped members have each status, so the agent sizes what it reads before reading any member, what each
    # status means, then which mapped members' text the captured requests held, by member, how many requests have no
    # query_source, which requests quote a logged request's path, which the scan could not read through, how complete
    # the scan was, and the files the scan wrote: none.
    class MembersInLoggedRequestsResult
      # The result from seen, the scan's report, as the request logging gives it.
      #: ({ members_by_status: Hash[String, Integer], members: Array[Hash[String, untyped]], orphans: Integer,
      #|    quoting_requests: Array[String], unreadable: Array[Hash[String, String]],
      #|    completeness: Hash[String, untyped] }) -> Hash[String, untyped]
      def result(seen)
        { "members_by_status" => seen[:members_by_status], "status_meanings" => LoggedRequestStatusMeanings.new.to_h,
          "members" => seen[:members], "orphans" => seen[:orphans],
          "quoting_requests" => seen[:quoting_requests], "unreadable" => seen[:unreadable],
          "completeness" => seen[:completeness], "wrote" => [] }
      end

      # --short: the count of members with each status, with how many requests the scan read, whether it read every
      # one through, since an absence holds only then, how many it could not read, and how many quote a logged
      # request, where a presence may be a quote; then one tab-separated line a member: its status, principle, member
      # key, with its id where it is now once moved, and the segments it was seen in, or - for none.
      #: ({ members_by_status: Hash[String, Integer], members: Array[Hash[String, untyped]], orphans: Integer,
      #|    quoting_requests: Array[String], unreadable: Array[Hash[String, String]],
      #|    completeness: Hash[String, untyped] }) -> Lines
      def short(seen)
        lines = [counts(seen), *seen[:members].map { member_line(it) }]
        Lines.new(stdout: lines.map { "#{it}\n" }.join, stderr: "", status: 0)
      end

      private

      # The counts by status, then what the scan read, as short prints it.
      #: ({ members_by_status: Hash[String, Integer], members: Array[Hash[String, untyped]], orphans: Integer,
      #|    quoting_requests: Array[String], unreadable: Array[Hash[String, String]],
      #|    completeness: Hash[String, untyped] }) -> String
      def counts(seen)
        completeness = seen[:completeness]
        whole = completeness.fetch("complete") ? "complete" : "not complete"
        read = "#{completeness.fetch("captured")} captured, #{whole}, #{seen[:unreadable].size} unreadable, " \
               "#{seen[:quoting_requests].size} quoting a logged request"
        "#{seen[:members_by_status].map { |status, count| "#{status} #{count}" }.join(", ")}; #{read}"
      end

      # One member's line: status, principle, member key, with its id where it is now once moved, and the distinct
      # segments it was seen in.
      #: (Hash[String, untyped]) -> String
      def member_line(member)
        segments = member.fetch("segments")
        [*member.values_at("status", "principle"), named(member), segments.empty? ? "-" : segments.join(",")].join("\t")
      end

      # member's key, followed by its id once a move has left the key naming where it was.
      #: (Hash[String, untyped]) -> String
      def named(member)
        key = member.fetch("member")
        member.key?("id") ? "#{key} (now #{member.fetch("id")})" : key
      end
    end
  end
end

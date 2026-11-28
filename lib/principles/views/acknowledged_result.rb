# typed: strict
# frozen_string_literal: true

require_relative "answered_request"
require_relative "invocation"
require_relative "../prose_list"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # An acknowledgement's answer accepted: the members that now read as judged, the files that hold them to
    # commit, and the command that no longer lists them.
    class AcknowledgedResult
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The acknowledgement of each of member_ids was accepted, and file holds them all; open_findings are the ids of
      # the findings the last audit left open on them, which it leaves open.
      #: (principle_id: String, member_ids: Array[String], file: String, ?open_findings: Array[String])
      #|   -> AnsweredRequest
      def several_acknowledged(principle_id:, member_ids:, file:, open_findings: [])
        AnsweredRequest.new(
          "status" => "acknowledged", "principle_id" => principle_id, "member_ids" => member_ids,
          "files_to_commit" => [file],
          "next_action" => "Commit #{file}. #{ProseList.new(member_ids)} read as judged until each is edited again.\n" \
                           "#{still_open(principle_id, open_findings)}This no longer lists them: " \
                           "#{@invocation.in_project("list-member-problems", principle_id, usage: "--short")}"
        )
      end

      # The acknowledgement of each of member_ids was accepted for every principle that maps it, each principle's in its
      # file, under its id in files; open_findings are, under a principle's id, the ids of the findings its last audit
      # left open on them, which it leaves open.
      #: (member_ids: Array[String], files: Hash[String, String], ?open_findings: Hash[String, Array[String]])
      #|   -> AnsweredRequest
      def across_acknowledged(member_ids:, files:, open_findings: {})
        AnsweredRequest.new(
          "status" => "acknowledged", "principle_ids" => files.keys, "member_ids" => member_ids,
          "files_to_commit" => files.values,
          "next_action" => "Commit #{ProseList.new(files.values)}. #{ProseList.new(member_ids)} read as judged until " \
                           "each is edited again.\n#{open_findings.map { |id, ids| still_open(id, ids) }.join}" \
                           "This no longer lists them: " \
                           "#{@invocation.in_project("list-member-problems", usage: "--short")}"
        )
      end

      # The acknowledgement was accepted and file holds it; open_findings are the ids of the findings the last audit
      # left open on the member, which it leaves open.
      #: (principle_id: String, member_id: String, file: String, ?open_findings: Array[String]) -> AnsweredRequest
      def acknowledged(principle_id:, member_id:, file:, open_findings: [])
        fields = {
          "status" => "acknowledged", "principle_id" => principle_id, "member_ids" => [member_id],
          "files_to_commit" => [file],
          "next_action" => "Commit #{file}. #{member_id} reads as judged until it is edited again.\n" \
                           "#{still_open(principle_id, open_findings)}This no longer lists it: " \
                           "#{@invocation.in_project("list-member-problems", principle_id, usage: "--short")}"
        }
        AnsweredRequest.new(fields)
      end

      private

      # The line saying that open_findings stay open, since only a full audit of principle_id decides one, with the
      # command that starts it; nothing when there are none.
      #: (String, Array[String]) -> String
      def still_open(principle_id, open_findings)
        return "" if open_findings.empty?

        stays, each = open_findings.one? ? %w[stays it] : %w[stay each]
        "#{ProseList.new(open_findings)} #{stays} open: an acknowledgement decides no finding, and the next full " \
          "audit decides #{each}: #{@invocation.in_project("start-audit", principle_id)}\n"
      end
    end
  end
end

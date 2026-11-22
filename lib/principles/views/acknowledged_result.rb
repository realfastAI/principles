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

      # The acknowledgement of each of member_ids was accepted, and file holds them all.
      #: (principle_id: String, member_ids: Array[String], file: String) -> AnsweredRequest
      def several_acknowledged(principle_id:, member_ids:, file:)
        AnsweredRequest.new(
          "status" => "acknowledged", "principle_id" => principle_id, "member_ids" => member_ids,
          "files_to_commit" => [file],
          "next_action" => "Commit #{file}. #{ProseList.new(member_ids)} read as judged until each is edited again.\n" \
                           "This no longer lists them: " \
                           "#{@invocation.in_project("list-member-problems", principle_id, usage: "--short")}"
        )
      end

      # The acknowledgement of each of member_ids was accepted for every principle that maps it, each principle's in its
      # file, under its id in files.
      #: (member_ids: Array[String], files: Hash[String, String]) -> AnsweredRequest
      def across_acknowledged(member_ids:, files:)
        AnsweredRequest.new(
          "status" => "acknowledged", "principle_ids" => files.keys, "member_ids" => member_ids,
          "files_to_commit" => files.values,
          "next_action" => "Commit #{ProseList.new(files.values)}. #{ProseList.new(member_ids)} read as judged until " \
                           "each is edited again.\nThis no longer lists them: " \
                           "#{@invocation.in_project("list-member-problems", usage: "--short")}"
        )
      end

      # The acknowledgement was accepted and file holds it.
      #: (principle_id: String, member_id: String, file: String) -> AnsweredRequest
      def acknowledged(principle_id:, member_id:, file:)
        fields = {
          "status" => "acknowledged", "principle_id" => principle_id, "member_ids" => [member_id],
          "files_to_commit" => [file],
          "next_action" => "Commit #{file}. #{member_id} reads as judged until it is edited again.\n" \
                           "This no longer lists it: " \
                           "#{@invocation.in_project("list-member-problems", principle_id, usage: "--short")}"
        }
        AnsweredRequest.new(fields)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "member_change_since_baseline"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # An acknowledgement's answer to fill as start-audit --member --as template prints it alone, where no request
    # stands beside it: the answer its request prints as response_template, with what that request shows beside it
    # for the agent to read, each member's role before its own fields and answer_with, the command that submits the
    # file the request's next_action saves it in. The answer reads neither.
    class AcknowledgementTemplateAlone
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # answer, whose members asked asks about, each as its member's part of the request holds it, with each role,
      # submitted from answer_file, the file the request's next_action saves it in.
      #: (Hash[String, untyped], Array[Hash[Symbol, untyped]], answer_file: String) -> Hash[String, untyped]
      def of(answer, asked, answer_file:)
        changes = asked.map { it.fetch(:change) } #: Array[MemberChangeSinceBaseline]
        printed(answer, changes.to_h { [it.member_id, { "role" => it.role }] }, answer_file)
      end

      # answer for the members several principles map, each principles' members as their part of the request holds
      # them: as of gives it, but with each member's roles, by the principle mapping it with each.
      #: (Hash[String, untyped], Hash[String, Array[Hash[Symbol, untyped]]], answer_file: String)
      #|  -> Hash[String, untyped]
      def across(answer, principles, answer_file:)
        roles = {} #: Hash[String, Hash[String, String]]
        principles.each do |principle_id, asked|
          asked.each do |member|
            change = member.fetch(:change) #: MemberChangeSinceBaseline
            (roles[change.member_id] ||= {})[principle_id] = change.role
          end
        end
        printed(answer, roles.transform_values { { "roles" => it } }, answer_file)
      end

      private

      # answer with each member's read_only fields before its own, and answer_with, submitting answer_file, after them.
      #: (Hash[String, untyped], Hash[String, Hash[String, untyped]], String) -> Hash[String, untyped]
      def printed(answer, read_only, answer_file)
        members = answer.fetch("members").to_h { |id, entry| [id, { **read_only.fetch(id), **entry }] }
        submit = @invocation.submit_answer(answer.fetch("request_id"), file: answer_file)
        { **answer, "members" => members, "answer_with" => submit }
      end
    end
  end
end

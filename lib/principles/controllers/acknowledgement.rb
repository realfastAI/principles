# typed: strict
# frozen_string_literal: true

require "time"
require_relative "answer_phase"
require_relative "../prose_list"
require_relative "member_acknowledgement"
require_relative "../models/acknowledgement"
require_relative "../models/reported_check"
require_relative "../views/acknowledgement_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # A one-member audit: start-audit ID --member MEMBER asks whether a committed change keeps that member's
    # meaning, and submit-answer moves its baseline in the audit record when the answer holds.
    class Acknowledgement < AnswerPhase
      # The request for principle id's member.
      #: (String, String) -> Hash[String, untyped]
      def start(id, member_id)
        naming_the_executable(rerun: one_member_audit(id)) do
          member = of(id, member_id)
          view.request(request_id: member.acknowledgement.request_id.to_s, principle_id: id, asked: member.asked)
              .merge("wrote" => [])
        end
      end

      # The answer alone, as start-audit --member --as template prints it, to fill and submit under the request's id.
      #: (String, String) -> Hash[String, untyped]
      def to_fill(id, member_id)
        naming_the_executable(rerun: one_member_audit(id)) do
          member = of(id, member_id)
          view.answer_to_fill(request_id: member.acknowledgement.request_id.to_s, asked: member.asked)
        end
      end

      # The result of answering, and the record it changes, not yet written.
      # @override
      #: (Models::SubmittedAnswer) -> [Views::AnsweredRequest, Array[Models::AuditRecord]]
      def answered(submitted)
        id = submitted.request_id.principle_id
        member = answering(submitted)
        [view.acknowledged(principle_id: id, member_id: member.member.id, file: @audit_records.file(id)),
         [accepted(member, submitted.response)]]
      end

      # The refusals an answer meets before its shape: any phase's, then a placeholder its template printed left in,
      # which the shape would refuse in meaning_kept without naming it, or in a checked member's exit_status
      # with a repair this template does not take.
      #: (Models::RequestId) -> Array[Models::RefusalBeforeShape]
      def before_shape(request_id) = [*super, left_as_printed]

      private

      # The record with member's baseline moved by its entry in response, a refusal of a field in the entry pointing
      # at it there.
      #: (MemberAcknowledgement, untyped) -> Models::AuditRecord
      def accepted(member, response)
        entry = member.acknowledgement.entry_in(response)
        Models::Acknowledgements.in_entry(member.member.id) { member.accepted(entry, at: Time.now.utc.iso8601) }
      end

      # The fields an answer may leave as its template printed them, read before its shape.
      #: () -> Models::AcknowledgementLeftAsPrinted
      def left_as_printed = Models::Acknowledgement::LEFT_AS_PRINTED

      # The placeholders a one-member audit's template prints, which its answer may leave as printed: its own, and
      # check_result's for a check the last audit ran, the only check it acknowledges. The member is in the
      # answer, not the request id, so this names the check's whether the member has one.
      # @override
      #: (Models::RequestId) -> Hash[String, untyped]?
      def printed_placeholders(_request_id)
        MemberAcknowledgement.placeholders(Models::ReportedCheck::UNCHANGED_PLACEHOLDERS.to_h
                                             .merge("exit_status" => Models::Acknowledgement::EXIT_STATUS_PLACEHOLDER))
      end

      # The one-member audit of principle id's member, as a refusal naming a near miss leads its repair with.
      #: (String) -> ^(String) -> String
      def one_member_audit(id)
        ->(member) { invocation.in_project("start-audit", id, options: ["--member", member]) }
      end

      # The member the answer acknowledges, refused as stale unless its request is still the one the answer answers.
      #: (Models::SubmittedAnswer) -> MemberAcknowledgement
      def answering(submitted)
        id = submitted.request_id.principle_id
        member = of(id, submitted.response.fetch("basis").fetch("member_ids").first)
        stale(id, member.member.id) unless member.acknowledgement.request_id == submitted.request_id
        member
      end

      # principle_id's member member_id, as its one-member audit asks and answers it.
      #: (String, String) -> MemberAcknowledgement
      def of(id, member_id) = handed(MemberAcknowledgement, principle_id: id, member_id:)

      # Refuses an answer to a request that no longer matches the project, naming the request for the same principles
      # and members.
      #: (String | Array[String], String | Array[String]) -> bot
      def stale(ids, member_ids)
        options = Array(member_ids).flat_map { ["--member", it] }
        raise Error.new("stale_request", "This request no longer matches #{ProseList.new(Array(ids))}: the member, " \
                                         "its baseline or the commit it was based on has changed since it was printed",
                        "Start it again and answer the new request: " \
                        "#{invocation.listed_in_project("start-audit", Array(ids), options:)}")
      end

      #: () -> Views::AcknowledgementResult
      def view
        Views::AcknowledgementResult.new(invocation)
      end
    end
  end
end

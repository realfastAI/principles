# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "acknowledgement_refusal"
require_relative "answer_place"
require_relative "audit_record"
require_relative "check_result_guide"
require_relative "listed_members"
require_relative "../prose_list"
require_relative "member"
require_relative "reported_check"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The run of its member's check that a one-member audit's answer reports: checked against the check
    # the record ran, carrying the line its last review rested on, and accepted only once it passed, since a
    # check that failed or could not run is a full audit's to judge.
    class AcknowledgedCheck
      # Where a one-member audit's answer gives its check_result, which a refusal of a field in it points into.
      CHECK_RESULT = AnswerPlace.new("/check_result", "The acknowledgement") #: AnswerPlace

      # record is the completed record the member is judged against. listed is what the member's check lists now,
      # when it is this tool's own list-member-problems, which exits 3 while it lists the member.
      #: (member: Member, principle_id: String, record: AuditRecord, ?listed: ListedMembers?) -> void
      def initialize(member:, principle_id:, record:, listed: nil)
        @member = member
        @principle_id = principle_id
        @record = record
        @listed = listed
        freeze
      end

      # The result the answer reports for the member's check, once it passed; nil for a member without a check,
      # whose answer may report none.
      #: (untyped) -> Hash[String, untyped]?
      def result(answer)
        check = @member.check
        refuse("it has no check, so its answer reports no check_result") if !check && answer.key?("check_result")
        return unless check

        sent = answer["check_result"] or missing
        passed(ReportedCheck.new(AnswerPlace.new("", "The acknowledgement"), check,
                                 ran: @record.check_run_for(@member.key), kept: @record.check_review_for(@member.key),
                                 guide: CheckResultGuide::ACKNOWLEDGEMENT)
                            .result(reported(sent, check)), sent)
      end

      private

      # result, once its check exited 0, or 3 for this tool's own list-member-problems while it lists only members
      # this answer acknowledges, which it lists no more once the record is committed. It always gives an
      # exit status, since the answer's schema refuses not_run_reason. sent is the check_result as given.
      #: (Hash[String, untyped], Hash[String, untyped]) -> Hash[String, untyped]
      def passed(result, sent)
        status = result.fetch("exit_status")
        command = result.fetch("command")
        return result if status.zero? || (status == 3 && lists_only_the_acknowledged?(command, sent))

        refuse("its check `#{command}` exited #{status}, so a full audit judges it")
      end

      # Whether the member's check is this tool's own list-member-problems and lists only members this answer
      # acknowledges, refusing a listed_members that is not what it lists now, and a listing of another member,
      # which it would still list once the record is committed.
      #: (String, Hash[String, untyped]) -> bool
      def lists_only_the_acknowledged?(command, sent)
        listed = @listed or return false
        misreported(command) unless listed.reported?(sent["listed_members"])
        others = listed.unacknowledged
        return true if others.empty?

        refuse("its check `#{command}` exited 3 and lists #{ProseList.new(others)}, which this " \
               "answer does not acknowledge, so a full audit judges it")
      end

      # Refuses a listed_members that is not what the member's own list-member-problems check lists now.
      #: (String) -> bot
      def misreported(command)
        raise CHECK_RESULT.child("listed_members").refusal(
          Error.new("invalid_answer", "check_result.listed_members is not what `#{command}` lists now",
                    "Run `#{command}` and give, under check_result.listed_members, the member id in the second " \
                    "column of each line it prints.")
        )
      end

      # The check_result the answer reports, its command read as the request printed it when left out.
      #: (untyped, String) -> untyped
      def reported(sent, check) = sent.is_a?(Hash) ? { "command" => check, **sent.except("listed_members") } : sent

      # Refuses an answer for a checked member that reports no check_result, naming the instruction and template slot
      # its request prints, not the full audit's answer_guide, which it does not.
      #: () -> bot
      def missing
        raise CHECK_RESULT.refusal(
          Error.new("invalid_check_result", "the member has a check, so its acknowledgement needs a check_result",
                    CheckResultGuide::ACKNOWLEDGEMENT.missing)
        )
      end

      #: (String) -> bot
      def refuse(why) = AcknowledgementRefusal.new(@member, @principle_id).refuse(why)
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Why a one-member audit cannot judge a member's change, as the audit record finds it: each sends the agent
    # to the full audit, but a member whose text is the one last judged needs nothing at all.
    class AcknowledgementRefusal
      # Why a one-member audit cannot judge member's change against record, or nil when it can: the record must
      # be completed and have assessed the member, the member's text must differ from the one it assessed, it must
      # be the project's, since a one-member audit reads its change from git, which holds no plugin's file, its check
      # must be the one the record ran, so none new, changed, removed or last not run escapes a full audit's review.
      # The one owner of these preconditions, which
      # list-member-problems asks before offering the audit that Acknowledgement refuses by them; git is
      # the callers' to know.
      #: (AuditRecord, Member, now_sha256: String?) -> AcknowledgementRefusal?
      def self.of(record, member, now_sha256:)
        members = record.members
        check = members.check_since(member.key, member.check)
        reason = baseline_missing(record, members.hash_for(member.key), now_sha256) ||
                 (:plugin if member.plugin_reference) || (check unless check == :unchanged)
        new(member, record.principle_id, reason, ran: members.check_run_for(member.key)) if reason
      end

      # Why record gives no baseline to judge a change against, the member's hash it assessed being recorded and
      # its hash now now_sha256: open, not completed, the member not assessed, or unchanged; nil when it gives one.
      #: (AuditRecord, String?, String?) -> Symbol?
      def self.baseline_missing(record, recorded, now_sha256)
        if record.open_after_a_completed_audit? then :open
        elsif !record.completed? then :not_completed
        elsif !recorded then :not_assessed
        elsif recorded == now_sha256 then :unchanged
        end
      end
      private_class_method :baseline_missing

      # principle_id is the member's principle, whose full audit each refusal names. reason, which raise! raises, is
      # :open, :not_completed, :not_assessed, :unchanged, :plugin, or how the member's check stands to the one the
      # record ran, as RecordedMembers#check_since says; ran is the command that record ran, if any. Without a reason
      # it only refuses for a reason its caller states.
      #: (Member, String, ?Symbol?, ?ran: String?) -> void
      def initialize(member, principle_id, reason = nil, ran: nil)
        @reason = reason
        @member = member
        @principle_id = principle_id
        @ran = ran
        freeze
      end

      # Refuses the member's acknowledgement for why, sending the agent to its principle's full audit instead.
      #: (String) -> bot
      def refuse(why)
        raise Error.new("cannot_acknowledge", "#{@member.id} cannot be acknowledged: #{why}",
                        "For a full audit instead: #{Error::EXECUTABLE} start-audit #{@principle_id}")
      end

      # Raises it.
      #: () -> bot
      def raise!
        case @reason
        when :unchanged then nothing_to_acknowledge
        when :open then open_audit
        when :not_completed then refuse("#{@principle_id} has no completed audit, so no baseline has been judged")
        when :not_assessed then refuse("no completed audit assessed #{@member.id}")
        when :plugin then refuse("it is read from an installed plugin, whose changes git holds no history of")
        else refuse("#{check_since_record}, so a full audit reviews it")
        end
      end

      private

      # How the member's check stands to the one the record ran, which a full audit reviews before it runs.
      #: () -> String
      def check_since_record
        case @reason
        when :removed then "its check was removed since the last completed audit ran `#{@ran}`"
        when :changed then "its check `#{@member.check}` changed since the last completed audit ran `#{@ran}`"
        when :not_run then "the last completed audit reported its check `#{@member.check}` not run"
        when :new then "its check `#{@member.check}` is new since the last completed audit"
        else raise ArgumentError, "unknown acknowledgement refusal #{@reason}"
        end
      end

      # A full audit open on a completed one, waiting on its correction: the step to finish, not a missing audit to
      # run, after which the member is acknowledged if it still differs from what that audit judged.
      #: () -> bot
      def open_audit
        raise Error.new("cannot_acknowledge",
                        "#{@member.id} cannot be acknowledged: #{@principle_id} has a full audit open, waiting on " \
                        "its correction",
                        "Submit that correction to complete the audit; then acknowledge this member if it is still " \
                        "listed as changed.")
                   .ending_with([Error::RepairCommand.new(purpose: "To start the full audit again instead",
                                                          command: "start-audit", values: [@principle_id])])
      end

      # A member whose text is the one last judged, as after a pure move, needs nothing: not an acknowledgement, and
      # not the full audit the other refusals send the agent to.
      #: () -> bot
      def nothing_to_acknowledge
        raise Error.new("cannot_acknowledge",
                        "#{@member.id}'s text is the one last judged, so there is nothing to acknowledge",
                        "Nothing needs doing.")
                   .ending_with([Error::RepairCommand.new(purpose: "After a committed edit changes it, acknowledge it",
                                                          command: "start-audit", values: [@principle_id],
                                                          options: ["--member", @member.id])])
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/audit"
require_relative "../models/other_templates_placeholders"
require_relative "../models/refusal_before_shape"
require_relative "../models/submitted_answer"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # What every phase of an audit shares in answering its request, which submit-answer and show-answer-check hand
    # over: each phase's controller answers for itself, so Answer never asks which phase it holds.
    # @abstract
    class AnswerPhase < Command
      # The result of answering, and each record change the answer makes, not yet written; every phase changes only
      # the request's own principle's record. Sorbet refuses a phase that does not define it, and takes an
      # abstract method only with a forwarding super for its body, which RuboCop would otherwise call useless.
      # @abstract
      #: (Models::SubmittedAnswer) -> [untyped, Array[Models::AuditRecord]]
      def answered(submitted) = super # rubocop:disable Lint/UselessMethodDefinition

      # The prior findings the request an answer's head names listed, once the phase has checked that request from
      # the head alone: none, unless the phase lists some.
      #: (Models::RequestId, Hash[String, untyped]) -> Models::PriorFindings?
      def checked_request(_request_id, _head) = nil

      # What each map entry a fix in the answer claims changed, which only a correction's fixes claim.
      #: (Models::SubmittedAnswer) -> Array[Hash[String, untyped]]
      def map_entry_changes(_submitted) = []

      # Each member the answer carries forward whose kept assessment names a prior finding it decides other than
      # still_holds, which only a full audit's assessment decides.
      #: (Models::SubmittedAnswer) -> Array[Hash[String, untyped]]
      def carried_naming_decided(_submitted) = []

      # Each prior finding whose write-up pointer the answer drops with null, with the pointer it had, which only a
      # full audit's assessment decides.
      #: (Models::SubmittedAnswer) -> Array[Hash[String, untyped]]
      def pointers_dropped(_submitted) = []

      # Each finding the record changes leave deferred with recorded_at null, which only a correction disposes of.
      #: (Array[Models::AuditRecord]) -> Array[String]
      def deferred_written_up_nowhere(_changes) = []

      # The refusals an answer to the request request_id names meets before its shape, in order; any phase's is a
      # placeholder its template did not print.
      #: (Models::RequestId) -> Array[Models::RefusalBeforeShape]
      def before_shape(request_id)
        [Models::OtherTemplatesPlaceholders.besides(printed_placeholders(request_id),
                                                    start_from: request_id.answer_to_fill)]
      end

      private

      # The placeholders the template of the request request_id names printed, which its answer may leave as
      # printed: none, unless the phase's template prints some.
      #: (Models::RequestId) -> Hash[String, untyped]?
      def printed_placeholders(_request_id) = nil

      # The audit of principle id, against its members' hashes now.
      #: (String) -> Models::Audit
      def audit_now(id)
        map = @principles.find(id)
        Models::Audit.new(map: map, now: @project.snapshots(map).hashes)
      end
    end
  end
end

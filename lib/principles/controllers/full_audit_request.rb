# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/audit"
require_relative "../models/instruction_named"
require_relative "../models/member_texts"
require_relative "../models/meta_principle"
require_relative "../models/part_named"
require_relative "../models/recent_decision"
require_relative "../models/reported_check"
require_relative "../views/assessment_request"
require_relative "../views/parts_index_result"
require_relative "last_record_notice_beside"
require_relative "members_to_assess"
require_relative "parts_to_read"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The request a full audit of one principle asks as the project stands, which Audit hands over for start-audit:
    # the commit it is based on, its id and what it asks. Starting writes nothing: the request id is a digest of what
    # the request depends on, so Answer checks the answer against the project as it is then.
    class FullAuditRequest < Command
      # The parts --part prints from the scan of the captured requests: its own alone, since the index, read first to
      # size the reads after it, leaves that part unsized rather than wait on the scan.
      SCANNED = [Views::LoggedRequestsEvidence::PART].freeze #: Array[String]

      # principle_id names the principle whose full audit is asked for; its map is refused unless it can be audited.
      #: (Models::Project, tool: RunningTool, principle_id: String) -> void
      def initialize(project, tool:, principle_id:)
        super(project, tool: tool)
        @id = principle_id
        map = @principles.auditable(principle_id)
        @base = @history.base_commit(principle_id, audited_files(map)) #: String?
        current = @project.snapshots(map)
        @audit = Models::Audit.new(map: map, now: current.hashes) #: Models::Audit
        listing = handed(MembersToAssess, principle_id: principle_id).listed(@audit, current)
        @listing = listing #: MembersToAssess::Listing
      end

      # The request as start-audit prints it, with each part's bytes as --part prints it, and a notice when the last
      # audit's record was left uncommitted.
      #: () -> Hash[String, untyped]
      def printed
        request = asked
        part_bytes = request_parts(request).part_bytes
        noticed = handed(LastRecordNoticeBeside, principle_id: @id, base: @base)
        audit_result.request(noticed.beside(audit_result.assessment_request(request, part_bytes:))).merge("wrote" => [])
      end

      # The answer alone, as start-audit --as template prints it, to fill and submit under the request's id.
      #: () -> Hash[String, untyped]
      def to_fill
        audit_result.answer_to_fill(asked(scanned: false))
      end

      # The instruction field this request prints, read on its own and whole, with the paragraphs for cases the
      # request does not hold; refused when it prints none by that name.
      #: (String) -> Hash[String, untyped]
      def instruction(field)
        request = asked(scanned: false)
        named = Models::InstructionNamed.new(field, principle_id: @id, printed: request.instruction_fields).field
        { "request_id" => request.request_id, named => request.whole_instruction(named), "wrote" => [] }
      end

      # The parts of this request each --part names, in the order given, printed together under the request's one
      # id, each member's in one members list, so the agent need not read the whole request for them, the index with
      # how to answer it, and one it leaves out for listing nothing as empty; the answer to fill bare, given alone, to
      # save as it stands; refused when the request has no part by one of the names.
      #: (Array[String]) -> Hash[String, untyped]
      def part(names)
        request = asked(scanned: names.intersect?(SCANNED))
        parts = request_parts(request)
        named = names.map { named_in(parts, it) }
        return parts.shown(Views::ContextParts::TEMPLATE) if named == [Views::ContextParts::TEMPLATE]

        shown = { "request_id" => request.request_id }.merge(parts.shown_together(named))
        answering(request, shown, named).merge("wrote" => [])
      end

      # The slots of the answer to fill that each --part names beside --as template, a member's as members/ID, in the
      # order given, printed together under the request's id; refused when the template has no slot by one name.
      #: (Array[String]) -> Hash[String, untyped]
      def slot_to_fill(names)
        request = asked(scanned: false)
        slots = request.slots_to_fill
        named = names.map { Models::PartNamed.new(it, principle_id: @id, printed: slots.keys, template: true).part }
        { "request_id" => request.request_id, "member_assessments" => named.map { slots.fetch(it) }, "wrote" => [] }
      end

      private

      # The parts of request that --part prints, each member's with its text now, or with that text in a part of its
      # own where MemberTexts says.
      #: (Views::AssessmentRequest) -> Views::ContextParts
      def request_parts(request)
        read = Models::MemberTexts.new(@project, @audit.map, listed: @listing.members)
        apart = Views::ContextParts::TextsApart.new(read.apart_ids, invocation, principle_id: @id,
                                                                                read_whole: read.read_whole)
        texts = Views::ContextParts::MemberTexts.new(read.lines, apart:)
        request.context_parts(texts:, optional: PartsToRead::OPTIONAL)
      end

      # The part name names in parts, refused when the request neither prints it nor leaves it out as empty.
      #: (Views::ContextParts, String) -> String
      def named_in(parts, name)
        Models::PartNamed.new(name, principle_id: @id, printed: parts.printable, empty: parts.left_out).part
      end

      # shown, the parts named printed from request, with how to answer the request when the index is among them.
      #: (Views::AssessmentRequest, Hash[String, untyped], Array[String]) -> Hash[String, untyped]
      def answering(request, shown, named)
        return shown unless named.include?(Views::ContextParts::INDEX)

        Views::PartsIndexResult.new(invocation).printed(shown, request)
      end

      # The request and what it asks, listing the findings the last completed audit left to decide, under an id that
      # digests them and the revision of that audit's record, but not the findings other principles leave
      # open on members sharing these lines. Unless scanned, its logged_requests part holds nothing, for a read that
      # prints none of it, since scanning the captured requests is slow.
      #: (?scanned: bool) -> Views::AssessmentRequest
      def asked(scanned: true)
        record = @audit_records.find(@id)
        prior = @audit.prior_findings(record)
        loads = loads_to_check(@audit).listed
        request_to_assess(answer_head(record, prior, loads),
                          handed(PartsToRead, audit: @audit, listing: @listing,
                                              audited_files: audited_files(@audit.map)).listed(prior, loads, scanned:))
      end

      # The head of the answer: the request's id, digesting prior, the findings the last completed audit left to
      # decide, and loads, what the request lists to check against the activation, with the basis it was printed on.
      #: (Models::AuditRecord?, Models::PriorFindings, Hash[String, untyped]?) -> Views::AnswerHead
      def answer_head(record, prior, loads)
        basis = audited_basis(Models::AssessmentBasis.printed(@base, record), @audit.map)
        Views::AnswerHead.new(request_id: @audit.assessment_id(basis, prior.digested, loads).to_s, basis: basis.to_h)
      end

      # What the agent assesses: the members, with what else it reads beside them.
      #: (Views::AnswerHead, Array[Views::RequestPart]) -> Views::AssessmentRequest
      def request_to_assess(head, parts)
        Views::AssessmentRequest.new(principle: { "principle_id" => @id, "description" => @audit.map.description },
                                     members: assessed_members, head: head,
                                     placeholders: { "recent_decision" => Models::RecentDecision::PLACEHOLDERS.to_h,
                                                     "collective_assessment" =>
                                                       Models::AssessmentAnswer::COLLECTIVE_PLACEHOLDER,
                                                     "new_finding" => Models::NewFindings::TEMPLATE,
                                                     "left_as_printed_rule" =>
                                                       Models::AssessmentAnswer::LEFT_AS_PRINTED_RULE },
                                     parts: parts)
      end

      # The members the request lists, each checked one's template printing the placeholders an answer leaves as
      # printed to give none.
      #: () -> Views::AssessedMembers
      def assessed_members
        Views::AssessedMembers.new(@listing.members,
                                   reviewed_check_placeholders: Models::ReportedCheck::PLACEHOLDERS.to_h,
                                   unchanged_check_placeholders: Models::ReportedCheck::UNCHANGED_PLACEHOLDERS.to_h,
                                   assessment_placeholder: Models::MemberAssessments::NAMED_PLACEHOLDER,
                                   carrier_checks: carrier_checks(@audit.map))
      end

      # The map's file and every member's file, which the base commit is judged over.
      #: (Models::Principle) -> Array[String]
      def audited_files(map) = @principles.audited_files(@id, map.members)
    end
  end
end

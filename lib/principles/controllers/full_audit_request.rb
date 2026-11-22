# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/audit"
require_relative "../models/instruction_named"
require_relative "../models/meta_principle"
require_relative "../models/part_named"
require_relative "../models/recent_decision"
require_relative "../models/reported_check"
require_relative "../views/assessment_request"
require_relative "../views/parts_index_result"
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

      # The request as start-audit prints it, with a notice when the last audit's record was left uncommitted.
      #: () -> Hash[String, untyped]
      def printed
        audit_result.request(with_record_notice(audit_result.assessment_request(asked))).merge("wrote" => [])
      end

      # The answer alone, as start-audit --as template prints it, to fill and submit under the request's id.
      #: () -> Hash[String, untyped]
      def to_fill
        audit_result.answer_to_fill(asked)
      end

      # The instruction field this request prints, read on its own and whole, with the paragraphs for cases the
      # request does not hold; refused when it prints none by that name.
      #: (String) -> Hash[String, untyped]
      def instruction(field)
        request = asked
        named = Models::InstructionNamed.new(field, principle_id: @id, printed: request.instruction_fields).field
        { "request_id" => request.request_id, named => request.whole_instruction(named), "wrote" => [] }
      end

      # The parts of this request each --part names, in the order given, printed together under the request's one
      # id, so the agent need not read the whole request for them, the index with how to answer it, and one it leaves
      # out for listing nothing as empty; the answer to fill bare, given alone, to save as it stands; refused when the
      # request has no part by one of the names.
      #: (Array[String]) -> Hash[String, untyped]
      def part(names)
        request = asked
        parts = request.context_parts(texts: member_texts, optional: PartsToRead::OPTIONAL)
        named = names.map { named_in(parts, it) }
        return parts.shown(Views::ContextParts::TEMPLATE) if named == [Views::ContextParts::TEMPLATE]

        shown = named.reduce({ "request_id" => request.request_id }) { |all, name| all.merge(parts.shown(name)) }
        answering(request, shown, named).merge("wrote" => [])
      end

      # The slots of the answer to fill that each --part names beside --as template, a member's as members/ID, in the
      # order given, printed together under the request's id; refused when the template has no slot by one name.
      #: (Array[String]) -> Hash[String, untyped]
      def slot_to_fill(names)
        request = asked
        slots = request.slots_to_fill
        named = names.map { Models::PartNamed.new(it, principle_id: @id, printed: slots.keys, template: true).part }
        { "request_id" => request.request_id, "member_assessments" => named.map { slots.fetch(it) }, "wrote" => [] }
      end

      private

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
      # open on members sharing these lines.
      #: () -> Views::AssessmentRequest
      def asked
        record = @audit_records.find(@id)
        prior = @audit.prior_findings(record)
        loads = loads_to_check(@audit).listed
        basis = Models::AssessmentBasis.printed(@base, record)
        head = Views::AnswerHead.new(request_id: @audit.assessment_id(basis, prior.digested, loads).to_s,
                                     basis: basis.to_h)
        request_to_assess(head, handed(PartsToRead, audit: @audit, listing: @listing,
                                                    audited_files: audited_files(@audit.map)).listed(prior, loads))
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
                                   assessment_placeholder: Models::MemberAssessments::NAMED_PLACEHOLDER)
      end

      # Each member's lines now, by id, without their line endings, so its part carries the text it is judged on.
      #: () -> Hash[String, Array[String]]
      def member_texts
        @audit.map.members.to_h { [it.id, @project.member_file(it.path).lines_of(it.locator).map(&:chomp)] }
      end

      # The map's file and every member's file, which the base commit is judged over.
      #: (Models::Principle) -> Array[String]
      def audited_files(map)
        [@principles.file(@id), *map.members.map(&:path)]
      end

      # The request, with a notice when the last audit's record was left uncommitted: a completed one to commit, or an
      # open one, which its correction completes, never to commit.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def with_record_notice(output)
        return output unless @base && uncommitted_record?

        file = @audit_records.file(@id)
        record = @audit_records.find(@id)
        left_open = record && !record.completed?
        notice = left_open ? audit_result.open_record_notice(file) : audit_result.uncommitted_record_notice(file)
        output.merge("notice" => notice)
      end

      # Whether the last audit's record exists but differs from the last commit, so it may be left behind.
      #: () -> bool
      def uncommitted_record?
        @audit_records.exist?(@id) && @history.uncommitted([@audit_records.file(@id)]).any?
      end
    end
  end
end

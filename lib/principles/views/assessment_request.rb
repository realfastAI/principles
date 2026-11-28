# typed: strict
# frozen_string_literal: true

require_relative "answer_head"
require_relative "assessment_answer_guide"
require_relative "assessed_members"
require_relative "context_parts"
require_relative "instruction"
require_relative "prompts"
require_relative "request_parts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One assessment request start-audit prints: the principle and its members as the agent assesses them, as
    # AssessedMembers, and the answer's template. Its hash travels in the request id, not here.
    class AssessmentRequest
      # The recent_decision the request's template prints, which names the other form in the guide beside it.
      IN_GUIDE = {
        "unavailable_reason" => "Or replace this object with answer_guide.recent_decision.examples.assessed " \
                                "as copy_from says."
      }.freeze #: Hash[String, String]
      # How mapped_elsewhere_instruction's paragraph on open findings elsewhere begins, which prints only when an
      # entry names one.
      OPEN_FINDINGS_ELSEWHERE = "Where an entry names `open_finding_ids`" #: String

      # The question every member's assessment answers, which a completed record digests with the description:
      # the whole question, what observed means too, however much of it a request prints, but not whether each rule
      # is enforced, which only the set's assessment answers.
      #: () -> String
      def self.question = question_paragraphs.join(" ")

      # The question's two parts: what to assess, and what observed means, which only a member judged afresh needs.
      #: () -> [String, String]
      def self.question_paragraphs
        [Prompts.text("assess-every-member/assess-each-member-and-the-set"),
         Prompts.text("assess-every-member/say-what-observed-means")]
      end

      # principle is the principle_id and description it names. head is what the answer hands back unchanged: the
      # request's id and its basis, the base commit and the last completed record's revision. parts are what the
      # agent reads beside the members before the question, such as the files outside the map that differ from the
      # base commit, each with any slots it adds to the template. placeholders is what the answer's own
      # fields print, by field, which their models own: collective_assessment's, which an answer may not send back,
      # and recent_decision's, each field of both its forms, in the template alone, which the agent fills one
      # of.
      #: (principle: Hash[String, untyped], members: AssessedMembers, head: AnswerHead,
      #|  placeholders: Hash[String, untyped], ?parts: Array[RequestPart]) -> void
      def initialize(principle:, members:, head:, placeholders:, parts: [])
        @principle = principle
        @placeholders = placeholders
        @members = members
        @head = head
        @parts = RequestParts.new(parts) #: RequestParts
        freeze
      end

      # The id the request is answered under.
      #: () -> String
      def request_id = @head.request_id

      # What the agent assesses, its other parts, the question and a guide to the answer's shapes.
      #: () -> Hash[String, untyped]
      def context
        listed = @principle.merge("members" => @members.shown, **@members.shared_check_instructions,
                                  **@members.carrier_checks)
        @parts.shown_after(listed).merge(asked)
      end

      # The fields the request prints an instruction under, in the order it prints them: the question, the answer
      # guide and each field named for an instruction.
      #: () -> Array[String]
      def instruction_fields = printed_instructions.map(&:field)

      # The parts of the context start-audit --part prints alone, each member's with its lines now, by id, from texts,
      # and each instruction field and the answer to fill as the request prints them; optional names each part the
      # context lists only when it holds something.
      #: (?texts: ContextParts::MemberTexts, ?optional: Array[String]) -> ContextParts
      def context_parts(texts: ContextParts::MemberTexts.new({}), optional: [])
        ContextParts.new(context, instruction_fields:, template:, texts:, optional:)
      end

      # Why the index gives no bytes, by the name of each part this read left unfilled.
      #: () -> Hash[String, String]
      def bytes_unknown = @parts.bytes_unknown

      # The principle the request audits.
      #: () -> String
      def principle_id = @principle.fetch("principle_id")

      # The instruction fields the request prints only in part, leaving out paragraphs for cases it does not hold.
      #: () -> Array[String]
      def trimmed_instruction_fields = printed_instructions.select(&:trimmed?).map(&:field)

      # The instruction field whole: every paragraph, the ones for cases the request does not hold too.
      #: (String) -> untyped
      def whole_instruction(field) = printed_instructions.find { it.field == field }&.whole

      # The answer to fill in: one assessment per member, and the set's.
      #: () -> Hash[String, untyped]
      def template
        @head.leading(@parts.slotted_after(assessed(IN_GUIDE, @members.templates)))
      end

      # The answer to fill in as printed alone, with no request beside it: each placeholder says what its field
      # takes, and points at nothing left unprinted, after one note saying how a field left as printed is
      # read, and the carried members whose check it still asks to run, named before the members so a
      # reader skipping carried markers still runs each.
      #: () -> Hash[String, untyped]
      def template_to_fill
        members = @members.templates
        filled = assessed(@placeholders.fetch("recent_decision"), members)
        @head.leading(@parts.filled_after({ "left_as_printed_rule" => @placeholders.fetch("left_as_printed_rule"),
                                            **@members.checks_to_fill(members), **filled,
                                            "findings" => [@placeholders.fetch("new_finding")] }))
      end

      # Whether a carried member's entry in the answer to fill prints a check_result slot to fill.
      #: () -> bool
      def carried_check_to_fill? = @members.carried_checked(@members.templates).any?

      # Each member's slot of the answer printed alone, as template_to_fill prints it, by its part name, members/ID.
      #: () -> Hash[String, Hash[String, untyped]]
      def slots_to_fill
        @members.templates.to_h { ["#{ContextParts::MEMBER}#{it.fetch("member_id")}", it] }
      end

      private

      # The answer's fields after its head and before its parts' slots, recent_decision and the members' templates as
      # given.
      #: (Hash[String, String], Array[Hash[String, untyped]]) -> Hash[String, untyped]
      def assessed(recent_decision, members)
        { "member_assessments" => members,
          "collective_assessment" => @placeholders.fetch("collective_assessment"),
          "recent_decision" => recent_decision, "findings" => [] }
      end

      # The instructions the request prints, in order: each part's, after its list, then its own.
      #: () -> Array[Instruction | GuideInstruction]
      def printed_instructions = [*@parts.instructions, *instructions].reject { it.printed.empty? }

      # What the request asks of what the agent read, each of its own instructions as the request prints it.
      #: () -> Hash[String, untyped]
      def asked = instructions.reduce({}) { |all, instruction| all.merge(instruction.printed) }

      # The request's own instructions: the question, why members are judged afresh, how to treat the members it
      # carries forward and the roles other principles give their lines, and the guide to the answer's shapes.
      #: () -> Array[Instruction | GuideInstruction]
      def instructions
        [question, judge_because_instruction,
         carried_forward_instruction, mapped_elsewhere_instruction, AssessmentAnswerGuide.new(@members).instruction]
      end

      # The question, defining observed only when a member is judged afresh, whose delivery it guides, then whether
      # each rule is enforced, which the set's assessment answers afresh at every audit. A record digests the question
      # without it, so asking it still carries forward each member's last assessment, which never answered it.
      #: () -> Instruction
      def question
        assess, observed = AssessmentRequest.question_paragraphs
        enforced = Prompts.text("assess-every-member/ask-whether-each-rule-is-enforced")
        Instruction.new("question", [[assess, true], [observed, @members.judged_afresh?], [enforced, true]])
      end

      # Why each member with judge_because is judged afresh, explaining only the values the members carry, so the
      # agent meets each value's meaning where it meets the value; nothing when no member gives one.
      #: () -> Instruction
      def judge_because_instruction
        reasons = @members.judge_because
        text = Prompts.text("assess-every-member/why-each-member-is-judged-again")
        Instruction.of_paragraphs("judge_because_instruction", text) do |paragraph|
          reasons.any? && (!paragraph.start_with?("`") || reasons.any? { paragraph.start_with?("`#{it}`:") })
        end
      end

      # How to judge the roles other principles give a member's lines, printed only when a member shares lines with
      # another principle's, and, when an entry names findings open on its member, where to read how to
      # treat them, which prints apart, before the question.
      #: () -> Instruction
      def mapped_elsewhere_instruction
        entries = @members.mapped_elsewhere
        open = entries.any? { |entry| entry["open_finding_ids"] }
        text = Prompts.text("assess-every-member/check-roles-other-principles-give-these-lines")
        Instruction.of_paragraphs("mapped_elsewhere_instruction", text) do |paragraph|
          entries.any? && (open || !paragraph.start_with?(OPEN_FINDINGS_ELSEWHERE))
        end
      end

      # How to answer when the request carries some members' last assessments forward; nothing when it carries none.
      # What a compact carried member shows, and what prints one whole, only when one prints compactly.
      #: () -> Instruction
      def carried_forward_instruction
        carry = Prompts.text("assess-every-member/judge-the-set-with-carried-assessments")
        compact = Prompts.text("assess-every-member/read-a-compact-carried-member")
        Instruction.new("carried_forward_instruction",
                        [[carry, @members.carried_forward?], [compact, @members.carried_compactly?]])
      end
    end
  end
end

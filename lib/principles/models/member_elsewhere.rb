# typed: strict
# frozen_string_literal: true

require_relative "line_span"
require_relative "member"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A member of another principle's map whose text shares a line with one located member: its principle, id,
    # role there and lines, and how its lines stand to the located member's: the same lines, all of them, within
    # them, or none of these, for a partial overlap. These are lines, not text, so what an
    # edit reaches is left to the agent.
    class MemberElsewhere
      # member is the other map's member, whose id and role are printed; span is its lines now.
      #: (principle_id: String, member: Member, span: LineSpan, located: LineSpan) -> void
      def initialize(principle_id:, member:, span:, located:)
        @principle_id = principle_id
        @member = member
        @span = span
        @relation = relation_to(located) #: String?
        @text_check_needed = text_check_needed_against?(located) #: bool
        freeze
      end

      # Whether the agent should check the text where the lines meet before deciding which edit reaches which
      # member: one holds the other's lines, and the one holding them is not a whole file.
      #: () -> bool
      def text_check_needed? = @text_check_needed

      # The principle whose map holds it.
      #: String
      attr_reader :principle_id

      # The findings among left_open, its principle's open findings, that name it.
      #: (Array[OpenFinding]) -> Array[OpenFinding]
      def open_among(left_open) = left_open.select { |finding| finding.on?(@member.key) }

      # Its entry, naming by id the findings among left_open that name it, which the request lists once, so the same
      # problem is not raised again in another principle's audit; as to_h when none do.
      #: (Array[OpenFinding]) -> Hash[String, untyped]
      def naming(left_open)
        on_it = open_among(left_open)
        on_it.empty? ? to_h : to_h.merge("open_finding_ids" => on_it.map(&:id))
      end

      # As add-member, show-principle and a full audit's request print it under mapped_elsewhere, its relation marked
      # true when it has one.
      #: () -> Hash[String, untyped]
      def to_h
        { "principle_id" => @principle_id, "member_id" => @member.id, "role" => @member.role,
          "first_line" => @span.first_line, "last_line" => @span.last_line, **(@relation ? { @relation => true } : {}) }
      end

      private

      #: (LineSpan) -> String?
      def relation_to(located)
        return "same_lines" if @span.same_lines_as?(located)
        return "spans_these_lines" if @span.holds?(located)

        "within_these_lines" if located.holds?(@span)
      end

      #: (LineSpan) -> bool
      def text_check_needed_against?(located)
        return !@span.holds_all_text_of?(located) if @relation == "spans_these_lines"
        return !located.holds_all_text_of?(@span) if @relation == "within_these_lines"

        false
      end
    end
  end
end

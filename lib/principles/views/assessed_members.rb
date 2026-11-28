# typed: strict
# frozen_string_literal: true

require_relative "check_result_template"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The members an assessment request lists, each a plain entry of id, role, first_line, last_line, the evidence
    # that locates it and, for a member with a check, the check whose result the template asks for: what the
    # request shows of each, the template entry each starts with, and what they carry that the request explains.
    class AssessedMembers
      # What the request shows of each member.
      SHOWN = %w[id role first_line last_line source check check_since_last_audit check_hidden_characters
                 acknowledged_since_last_audit carried_forward open_finding_ids judge_because moved_from read_the_change
                 changed_lines mapped_elsewhere].freeze #: Array[String]

      # reviewed_check_placeholders is the text a checked member's template prints in each field it may leave as
      # printed to give none, for a check reviewed before it runs; unchanged_check_placeholders, for one the
      # last audit ran.
      # assessment_placeholder is the text a fresh member's assessment prints, which an answer may not send back, its
      # %<id>s filled with the member's id, so each slot's is its own and one edit fills one slot.
      # carrier_checks is the check for each carrier kind the members are in, as CarrierChecks prints them.
      #: (Array[Hash[String, untyped]], reviewed_check_placeholders: Hash[String, String],
      #|  unchanged_check_placeholders: Hash[String, String], assessment_placeholder: String,
      #|  ?carrier_checks: Hash[String, untyped]) -> void
      def initialize(members, reviewed_check_placeholders:, unchanged_check_placeholders:, assessment_placeholder:,
                     carrier_checks: {})
        @assessment_placeholder = assessment_placeholder
        @carrier_checks = carrier_checks
        @members = members
        @reviewed_check_placeholders = reviewed_check_placeholders
        @unchanged_check_placeholders = unchanged_check_placeholders
        freeze
      end

      # What the request shows of a carried member no flag fires on: what names it and its check, whose result
      # the template still asks for, and of its carried assessment only its dates and flags.
      COMPACT = %w[id role source check check_since_last_audit check_hidden_characters
                   carried_forward].freeze #: Array[String]
      # What a compact member shows of its carried assessment.
      CARRIED_COMPACTLY = %w[assessed_at observed_at observed_at_from_assessed_at evidence_changed
                             file_changed_outside_member].freeze #: Array[String]

      # Each member as the request's context shows it, its fields in SHOWN's order; a carried member no flag fires on
      # compactly, as COMPACT and CARRIED_COMPACTLY say, its stored assessment one show-audit away.
      #: () -> Array[Hash[String, untyped]]
      def shown
        @members.map do |member|
          next fields(member, SHOWN).merge(instruction(member)) unless compact?(member)

          fields(member, COMPACT).merge(instruction(member),
                                        "carried_forward" => member.fetch("carried_forward").slice(*CARRIED_COMPACTLY))
        end
      end

      # The check for each carrier kind the members are in, under carrier_checks, which the request prints beside
      # them, outside the question a record digests; nothing when there are none.
      #: () -> Hash[String, Hash[String, untyped]]
      def carrier_checks = @carrier_checks.empty? ? {} : { "carrier_checks" => @carrier_checks }

      # What the template printed alone says of the checks before its members, since it has no context to show it in:
      # the carried members whose template entry in templates still asks for a check_result, under
      # carried_checks_to_run, named before the members so a reader skipping carried markers still runs each, and how
      # to run and report the checks of each standing under shared_check_instructions, and each checked member's own
      # lines by id under check_instructions; each only when it lists any.
      #: (Array[Hash[String, untyped]]) -> Hash[String, untyped]
      def checks_to_fill(templates)
        carried = carried_checked(templates)
        instructions = @members.to_h { [it.fetch("id"), check_template(it)&.own_instruction] }.compact
        { "carried_checks_to_run" => carried, **shared_check_instructions, "check_instructions" => instructions }
          .reject { _2.empty? }
      end

      # The id of each carried member whose entry in templates still asks for a check_result.
      #: (Array[Hash[String, untyped]]) -> Array[String]
      def carried_checked(templates)
        templates.select { it["carried_forward"] && it.key?("check_result") }.map { it.fetch("member_id") }
      end

      # How to run and report the checks of each standing, once, with the ids of the members it is for, under
      # shared_check_instructions, whose own lines check_instructions adds; nothing when none has a check.
      #: () -> Hash[String, Hash[String, untyped]]
      def shared_check_instructions
        checks = @members.filter_map { |member| check_template(member)&.then { [member.fetch("id"), it] } }
        return {} if checks.empty?

        { "shared_check_instructions" => checks.group_by { |_, template| template.status }.map do |_, grouped|
          { "member_ids" => grouped.map(&:first), "instruction" => grouped.fetch(0).last.shared_instruction }
        end }
      end

      # Each member's template entry: a fresh assessment to fill in, or, for a member whose last assessment is
      # carried forward, the marker that keeps it; either with its check's result when it has a check.
      #: () -> Array[Hash[String, untyped]]
      def templates = @members.map { |member| template(member) }

      # Whether any member has a check, whose result's shapes the answer guide then shows.
      #: () -> bool
      def checked? = @members.any? { |member| member["check"] }

      # Whether any member's check is new or changed, so no audit ran it as it is now, to review before it runs.
      #: () -> bool
      def check_to_review?
        @members.any? { |member| member["check"] && member.dig("check_since_last_audit", "status") != "unchanged" }
      end

      # Whether the request carries any member's last assessment forward.
      #: () -> bool
      def carried_forward? = @members.any? { |member| member["carried_forward"] }

      # Whether any member is judged afresh, whose template then gives a delivery.
      #: () -> bool
      def judged_afresh? = @members.any? { |member| !member["carried_forward"] }

      # Whether a carried member no flag fires on prints compactly, with no assessment.
      #: () -> bool
      def carried_compactly? = @members.any? { |member| compact?(member) }

      # Each reason a member is judged afresh, once.
      #: () -> Array[String]
      def judge_because = @members.filter_map { |member| member["judge_because"] }.uniq

      # Each entry naming another principle's role for a member's lines.
      #: () -> Array[Hash[String, untyped]]
      def mapped_elsewhere = shown.flat_map { |member| member["mapped_elsewhere"] || [] }

      private

      # Whether member is carried with no flag firing on it, so it prints compactly.
      #: (Hash[String, untyped]) -> bool
      def compact?(member) = member["carried_forward"] && !member["flagged"]

      # member's fields named in names, in that order.
      #: (Hash[String, untyped], Array[String]) -> Hash[String, untyped]
      def fields(member, names) = names.select { member.key?(it) }.to_h { [it, member[it]] }

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def template(member)
        assessed = member["carried_forward"] ? carried(member) : fresh(member)
        template = check_template(member)
        template ? assessed.merge("check_result" => template.to_h) : assessed
      end

      # The check_result template of a checked member, with its instruction; nil for one without a check.
      #: (Hash[String, untyped]) -> CheckResultTemplate?
      def check_template(member)
        CheckResultTemplate.for(member, reviewed_placeholders: @reviewed_check_placeholders,
                                        unchanged_placeholders: @unchanged_check_placeholders)
      end

      # The member's own check_instruction, as the request's context shows it beside the member; none without a check
      # or without lines of its own beside shared_check_instructions.
      #: (Hash[String, untyped]) -> Hash[String, String]
      def instruction(member)
        own = check_template(member)&.own_instruction or return {}
        { "check_instruction" => own }
      end

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def carried(member) = { "member_id" => member.fetch("id"), "carried_forward" => true }

      # A fresh member's slot, naming why it is judged afresh, so the template printed alone says so too.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def fresh(member)
        id = member.fetch("id")
        { "member_id" => id, **member.slice("judge_because"), "assessment" => format(@assessment_placeholder, id:),
          "delivery" => "not_observed", "evidence" => member.fetch("evidence") }
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "time"
require_relative "acknowledgement"
require_relative "../models/acknowledgements"
require_relative "../models/acknowledgements_across"
require_relative "../models/members_across_principles"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # Several members acknowledged in one request and one answer: start-audit ID with --member given more
    # than once asks about each as its own one-member audit would, and submit-answer moves every baseline or none.
    class Acknowledgements < Acknowledgement
      # The request for several of principle id's members in one answer, or with to_fill its answer alone:
      # each member as its own request shows it.
      #: (String, Array[String], to_fill: bool) -> Hash[String, untyped]
      def several(id, member_ids, to_fill:)
        naming_the_executable(rerun: one_member_audit(id)) do
          members = member_ids.map { of(id, it) }
          request_id = several_of(id, members).request_id.to_s
          asked = members.map(&:asked)
          next view.several_to_fill(request_id:, members: asked) if to_fill

          view.several_request(request_id:, principle_id: id, members: asked).merge("wrote" => [])
        end
      end

      # The request for the members several principles map, each principle acknowledging those of member_ids it maps,
      # in one answer judging each member once, or with to_fill its answer alone.
      #: (Array[String], Array[String], to_fill: bool) -> Hash[String, untyped]
      def across(ids, member_ids, to_fill:)
        naming_the_executable(rerun: across_audit(ids, member_ids)) do
          by_principle = members_by_principle(ids, member_ids)
          request_id = across_of(by_principle).request_id.to_s
          principles = by_principle.transform_values { it.map(&:asked) }
          next view.across_to_fill(request_id:, principles:) if to_fill

          view.across_request(request_id:, principles:, keeping_deferred: keeping_deferred(by_principle))
              .merge("wrote" => [])
        end
      end

      # The result of answering a request for several members, and the one record their acknowledgements change.
      # @override
      #: (Models::SubmittedAnswer) -> [Views::AnsweredRequest, Array[Models::AuditRecord]]
      def answered(submitted)
        return across_answered(submitted) if submitted.response.fetch("basis").key?("principle_ids")

        id = submitted.request_id.principle_id
        several, members = answering_several(submitted)
        [view.several_acknowledged(principle_id: id, member_ids: members.map { it.member.id },
                                   file: @audit_records.file(id)),
         [all_accepted(several, members, submitted.response)]]
      end

      private

      # The principles in by_principle with a member whose acknowledgement keeps a deferred finding.
      #: (Hash[String, Array[MemberAcknowledgement]]) -> Array[String]
      def keeping_deferred(by_principle)
        by_principle.select { |_, members| members.any? { it.acknowledgement.keeps_deferred_findings? } }.keys
      end

      # The result of answering a request for the members several principles map, and each principle's record, which
      # are written only once every one of them is accepted.
      #: (Models::SubmittedAnswer) -> [Views::AnsweredRequest, Array[Models::AuditRecord]]
      def across_answered(submitted)
        across, by_principle = answering_across(submitted.response.fetch("basis"), submitted.request_id)
        records = across.accepted(submitted.response) do |id, several, answer|
          all_accepted(several, by_principle.fetch(id), answer, acknowledging: across.acknowledging)
        end
        [view.across_acknowledged(member_ids: across.member_ids,
                                  files: by_principle.keys.to_h { [it, @audit_records.file(it)] }), records]
      end

      # The members each principle basis names maps, refused when a later copy wrote any of their records, or as stale
      # unless their request is still the one request_id names.
      #: (Hash[String, untyped], Models::RequestId)
      #|   -> [Models::AcknowledgementsAcross, Hash[String, Array[MemberAcknowledgement]]]
      def answering_across(basis, request_id)
        ids = basis.fetch("principle_ids")
        ids.each { @audit_records.refuse_newer(it, version: @tool.version) }
        by_principle = members_by_principle(ids, basis.fetch("member_ids"))
        across = across_of(by_principle)
        stale(ids, basis.fetch("member_ids")) unless across.request_id == request_id
        [across, by_principle]
      end

      # The members the answer acknowledges, refused as stale unless their request is still the one it answers.
      #: (Models::SubmittedAnswer) -> [Models::Acknowledgements, Array[MemberAcknowledgement]]
      def answering_several(submitted)
        id = submitted.request_id.principle_id
        members = submitted.response.fetch("basis").fetch("member_ids").map { of(id, it) }
        several = several_of(id, members)
        stale(id, members.map { it.member.id }) unless several.request_id == submitted.request_id
        [several, members]
      end

      # The record with each member's acknowledgement in it, once the answer holds for every one of them.
      # acknowledging is the members the whole answer acknowledges, each as its principle id and member id, which a
      # member's own list-member-problems check may list: several's own unless the answer is across principles.
      #: (Models::Acknowledgements, Array[MemberAcknowledgement], untyped, ?acknowledging: Array[[String, String]])
      #|  -> Models::AuditRecord
      def all_accepted(several, members, response, acknowledging: several.acknowledging)
        at = Time.now.utc.iso8601
        by_id = members.to_h { [it.member.id, it] }
        several.accepted(response) do |member_id, entry, into|
          by_id.fetch(member_id).accepted(entry, at:, acknowledging:, into:)
        end
      end

      # The acknowledgements of the members each principle maps, under its id, in one request.
      #: (Hash[String, Array[MemberAcknowledgement]]) -> Models::AcknowledgementsAcross
      def across_of(by_principle)
        checked = by_principle.transform_values { |members| members.select { it.member.check }.map { it.member.id } }
        Models::AcknowledgementsAcross.new(by_principle.to_h { |id, members| [id, several_of(id, members)] }, checked:)
      end

      # Each of the principles ids names, in id order, with those of member_ids it maps, as MembersAcrossPrinciples
      # refuses them.
      #: (Array[String], Array[String]) -> Hash[String, Array[MemberAcknowledgement]]
      def members_by_principle(ids, member_ids)
        mapped_across(ids, member_ids).by_principle.to_h { |id, mapped| [id, mapped.map { of(id, it) }] }
      end

      # The request across principles ids for member_ids, with the first member none of them maps replaced by member,
      # as a refusal naming a near miss leads its repair with.
      #: (Array[String], Array[String]) -> ^(String) -> String
      def across_audit(ids, member_ids)
        lambda do |member|
          missing = mapped_across(ids, member_ids).unmapped
          named = member_ids.map { it == missing ? member : it }
          invocation.listed_in_project("start-audit", ids.uniq.sort, options: named.flat_map { ["--member", it] })
        end
      end

      # member_ids as the principles ids names map them.
      #: (Array[String], Array[String]) -> Models::MembersAcrossPrinciples
      def mapped_across(ids, member_ids)
        Models::MembersAcrossPrinciples.new(ids.map { @principles.find(it) }, member_ids)
      end

      # The acknowledgements of several of principle id's members, each under its member's id, in one request.
      #: (String, Array[MemberAcknowledgement]) -> Models::Acknowledgements
      def several_of(id, members)
        named = members.map { [it.member.id, it.acknowledgement.request_id] }
        Models::Acknowledgements.of(principle_id: id, members: named)
      end
    end
  end
end

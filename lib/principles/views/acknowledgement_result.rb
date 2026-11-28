# typed: strict
# frozen_string_literal: true

require_relative "answer_in_a_file"
require_relative "invocation"
require_relative "member_change_since_baseline"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A one-member audit's request and its result.
    class AcknowledgementResult
      # Where a placeholder names the entry it prints in, by its position in the template's members, 1 the first.
      SLOT = "%<id>s" #: String

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # asked is what the request asks of its member: under :change its change since its baseline; under :context
      # what the request's context shows beside it, such as the record's findings on the member; and under
      # :placeholders the text the template prints in each field the agent writes. What the agent judges is under
      # context, the question first, so an agent reading the request's head finds what it is asked before the text.
      # answer_file is the file its next_action saves the answer in, as in each request below.
      #: (request_id: String, principle_id: String, asked: Hash[Symbol, untyped], answer_file: String)
      #|  -> Hash[String, untyped]
      def request(request_id:, principle_id:, asked:, answer_file:)
        { "status" => "agent_judgement_required", "request_id" => request_id, "phase" => "acknowledgement",
          "context" => { "principle_id" => principle_id,
                         "question" => Prompts.text("acknowledge-a-change/say-whether-the-change-keeps-the-meaning"),
                         **asked.fetch(:change).to_h, **asked.fetch(:context) },
          "response_template" => answer_to_fill(request_id:, asked:),
          "answer_with" => @invocation.submit_answer(request_id),
          "next_action" => to_fill([principle_id], [asked.fetch(:change).member_id], request_id:, file: answer_file) }
      end

      # The answer to the request request_id names, to fill: the request prints it as response_template, and
      # start-audit --member --as template prints it alone, each field the agent writes holding its placeholder,
      # and only those: the fields the answer may add, the question names, under members by the member's id,
      # as several members' are, and its basis names it under member_ids, as theirs do.
      #: (request_id: String, asked: Hash[Symbol, untyped]) -> Hash[String, untyped]
      def answer_to_fill(request_id:, asked:)
        member_id = asked.fetch(:change).member_id
        { "request_id" => request_id, "basis" => { "member_ids" => [member_id] },
          "members" => { member_id => named(asked.fetch(:placeholders), 1) } }
      end

      # The request for several members' acknowledgements in one answer: each of members holds a member's
      # change, the context its own request shows beside it and the placeholders its template prints, as one member's
      # request holds them, under context.members and the template's members in the order the agent named them. The
      # question leads the context, so an agent reading the request's head finds what it is asked before the members.
      #: (request_id: String, principle_id: String, members: Array[Hash[Symbol, untyped]], answer_file: String)
      #|  -> Hash[String, untyped]
      def several_request(request_id:, principle_id:, members:, answer_file:)
        { "status" => "agent_judgement_required", "request_id" => request_id, "phase" => "acknowledgements",
          "context" => { "principle_id" => principle_id,
                         "question" => Prompts.text("acknowledge-a-change/say-whether-each-change-keeps-its-meaning"),
                         "members" => shown(members) },
          "response_template" => several_to_fill(request_id:, members:),
          "answer_with" => @invocation.submit_answer(request_id),
          "next_action" => to_fill([principle_id], members.map { it.fetch(:change).member_id },
                                   request_id:, file: answer_file) }
      end

      # The answer to the request for several members request_id names, to fill: its basis names each member, and
      # its members hold each one's placeholders under its id, as start-audit --as template prints it alone.
      #: (request_id: String, members: Array[Hash[Symbol, untyped]]) -> Hash[String, untyped]
      def several_to_fill(request_id:, members:)
        { "request_id" => request_id, "basis" => { "member_ids" => members.map { it.fetch(:change).member_id } },
          "members" => members.each_with_index.to_h { |asked, index| named_entry(asked, index + 1) } }
      end

      # The request for the members several principles map in one answer: under context.principles, each
      # principle's members as its own request for several shows them, and in the template one entry per member,
      # judged once for every principle that maps it. keeping_deferred names each principle whose members keep a
      # deferred finding, which the request says only a full audit resolves. The question leads the context, as in
      # one principle's requests.
      #: (request_id: String, principles: Hash[String, Array[Hash[Symbol, untyped]]], answer_file: String,
      #|  ?keeping_deferred: Array[String]) -> Hash[String, untyped]
      def across_request(request_id:, principles:, answer_file:, keeping_deferred: [])
        { "status" => "agent_judgement_required", "request_id" => request_id, "phase" => "acknowledgements",
          "context" => { "question" => across_question, "principles" => shown_once(principles),
                         **deferred_findings_kept(keeping_deferred) },
          "response_template" => across_to_fill(request_id:, principles:),
          "answer_with" => @invocation.submit_answer(request_id),
          "next_action" => to_fill(principles.keys.uniq.sort, across_member_ids(principles),
                                   request_id:, file: answer_file) }
      end

      # The answer to the request for the members several principles map, to fill: its basis names each principle and
      # each member, and its members hold one entry per member, with every field any principle's template prints for
      # it, so check_result is there when any principle checks it, and the first principle's text where two
      # print the same field.
      #: (request_id: String, principles: Hash[String, Array[Hash[Symbol, untyped]]]) -> Hash[String, untyped]
      def across_to_fill(request_id:, principles:)
        entries = across_entries(principles)
        { "request_id" => request_id, "basis" => { "principle_ids" => principles.keys, "member_ids" => entries.keys },
          "members" => entries }
      end

      private

      # One entry per member the principles' requests ask about, by its id, with every field any principle's template
      # prints for it, the first principle's text where two print the same field, its placeholders naming its position.
      #: (Hash[String, Array[Hash[Symbol, untyped]]]) -> Hash[String, Hash[String, untyped]]
      def across_entries(principles)
        ids = across_member_ids(principles)
        principles.values.flatten.each_with_object({}) do |asked, by_member|
          id = asked.fetch(:change).member_id
          by_member[id] = named(asked.fetch(:placeholders), ids.index(id).to_i + 1).merge(by_member.fetch(id, {}))
        end
      end

      # placeholders with each one's SLOT naming the entry's position, as its entry in the template prints them; any
      # other text, a percent sign included, as it is.
      #: (Hash[String, untyped], Integer) -> Hash[String, untyped]
      def named(placeholders, position)
        placeholders.transform_values { it.is_a?(String) ? it.gsub(SLOT, position.to_s) : it }
      end

      # The template's entry for the member asked asks about, by its id, its placeholders naming its position.
      #: (Hash[Symbol, untyped], Integer) -> [String, Hash[String, untyped]]
      def named_entry(asked, position) = [asked.fetch(:change).member_id, named(asked.fetch(:placeholders), position)]

      # How to fill the answer to request_id, acknowledging member_ids of principle_ids: saved bare from
      # start-audit --as template to file, which the agent edits.
      #: (Array[String], Array[String], request_id: String, file: String) -> String
      def to_fill(principle_ids, member_ids, request_id:, file:)
        AnswerInAFile.new(@invocation).acknowledgement(principle_ids, member_ids, request_id:, file:)
      end

      # Each member the principles' requests ask about, once, in the order they ask.
      #: (Hash[String, Array[Hash[Symbol, untyped]]]) -> Array[String]
      def across_member_ids(principles) = principles.values.flatten.map { it.fetch(:change).member_id }.uniq

      # Where to read the deferred findings an acknowledgement across principles keeps, and the full audit of each
      # principle in ids that resolves them, one command to a line; nothing when ids is empty.
      #: (Array[String]) -> Hash[String, String]
      def deferred_findings_kept(ids)
        return {} if ids.empty?

        read = Prompts.text("acknowledge-a-change/read-the-deferred-findings-it-keeps",
                            list_open_findings: @invocation.in_project("list-open-findings", options: ["--lines"]))
        audits = ids.map do |id|
          Prompts.text("acknowledge-a-change/resolve-them-in-a-full-audit",
                       principle_id: id, start_audit: @invocation.in_project("start-audit", id))
        end
        { "deferred_findings_kept" => [read, *audits].join("\n") }
      end

      # The question a request across principles asks: judge each member once, then as several members are judged.
      #: () -> String
      def across_question
        once = Prompts.text("acknowledge-a-change/judge-each-member-once-for-every-principle")
        "#{once} #{Prompts.text("acknowledge-a-change/say-whether-each-change-keeps-its-meaning")}"
      end

      # Each principle's members as shown, a member an earlier principle already shows with the same change naming that
      # principle under change_shown_under in place of the change, so its lines print once.
      #: (Hash[String, Array[Hash[Symbol, untyped]]]) -> Hash[String, Hash[String, untyped]]
      def shown_once(principles)
        first = {} #: Hash[String, [String, MemberChangeSinceBaseline]]
        principles.to_h do |principle_id, members|
          [principle_id, { "members" => members.map do |asked|
            change = asked.fetch(:change)
            earlier, shown = first[change.member_id] ||= [principle_id, change]
            repeated = earlier != principle_id && shown.same_change_as?(change)
            { **(repeated ? change.shown_under(earlier) : change.to_h), **asked.fetch(:context) }
          end }]
        end
      end

      # Each member's change and the context beside it, as its own request shows them.
      #: (Array[Hash[Symbol, untyped]]) -> Array[Hash[String, untyped]]
      def shown(members) = members.map { { **it.fetch(:change).to_h, **it.fetch(:context) } }
    end
  end
end

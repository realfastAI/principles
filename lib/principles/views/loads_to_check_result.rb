# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "prompts"
require_relative "request_part"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # How a full audit's request shows the members to check against the principle's activation.
    class LoadsToCheckResult
      # The part this lists, by the name the request prints it under and start-audit --part takes.
      PART = "loads_to_check_against_activation" #: String

      # What a decision may be, as the answer printed alone says where it is written.
      DECISION = "accepted, with reason saying why the member loads as it does; kept, with no reason, where " \
                 "last_accepted.since_accepted is unchanged; if the activation is wrong instead, change it and " \
                 "start the audit again" #: String

      # listed is the members to check, nil when there are none, and id the principle they belong to; placeholders
      # is the text the template alone prints in each field of a decision beside it, which left is not given.
      #: (Invocation, Hash[String, untyped]?, String, placeholders: Hash[String, String]) -> void
      def initialize(invocation, listed, id, placeholders:)
        @placeholders = placeholders
        @invocation = invocation
        @listed = listed
        @id = id
        freeze
      end

      # The request's part that lists the members to check against the activation, how to decide them, and a
      # decision to fill in for each; nil when there are none to list.
      #: () -> RequestPart?
      def part
        listed = @listed or return

        decisions = listed.fetch("rows").map { |row| { "member_id" => row.fetch("member_id"), "decision" => nil } }
        RequestPart.new(shown: { PART => listed },
                        instructions: [Instruction.of_paragraphs("loads_to_check_instruction", instruction) { true }],
                        slots: { "loading_decisions" => decisions },
                        help: { "loading_decisions" => { "decision" => DECISION, **@placeholders } })
      end

      private

      # How to decide each listed member, naming the activation change for a principle whose work is in hand in
      # every session.
      #: () -> String
      def instruction
        always = @invocation.in_project("change-activation", @id, options: ["--always"])
        Prompts.text("assess-every-member/decide-each-member-loading", always: always)
      end
    end
  end
end

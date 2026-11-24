# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "prompts"
require_relative "shell_word"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # show-first-audit-brief's result: the instructions one background subagent follows to run a principle's first
    # full audit, each command filled for that principle, so the subagent types no id.
    class FirstAuditBrief
      # What the list asks, which the commands, one a line, follow.
      PICK_ONE = "Leave out any your instructions or memory say to skip, and follow the brief of one, which its " \
                 "command prints:"

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The brief for principle id.
      #: (String) -> Hash[String, untyped]
      def result(id)
        { "principle" => id,
          "brief" => Prompts.text("run-a-first-audit-in-the-background/follow-the-brief",
                                  id: id, answer_file: ShellWord.new(@invocation.answer_file(id)).to_s,
                                  index: @invocation.in_project("start-audit", id, options: ["--part", "index"]),
                                  template: @invocation.in_project("start-audit", id, options: ["--as", "template"])),
          "wrote" => [] }
      end

      # The principles awaiting a first full audit, ids, as list-member-problems names them, with each one's brief
      # command on a line of its own, for the subagent to pick one from.
      #: (Array[String]) -> Hash[String, untyped]
      def awaiting(ids)
        { "awaiting_first_audit" => ids, "next_action" => pick_one(ids), "wrote" => [] }
      end

      private

      #: (Array[String]) -> String
      def pick_one(ids)
        return "Every mapped principle has had a full audit, so there is no first audit to run." if ids.empty?

        [PICK_ONE, *ids.map { @invocation.in_project("show-first-audit-brief", it) }].join("\n")
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "problem_lines"
require_relative "shell_word"
require_relative "../prose_list"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The one-member audits list-member-problems offers: by the principles that acknowledge them together, in the
    # order the model gives, the changed members each acknowledgement takes in, one command for each set, and those
    # whose check is this tool's own list-member-problems --short, which the model puts last.
    class AcknowledgementsOffered
      # groups gives, for each set of principle ids, the members they acknowledge together; last, the members whose
      # check is this tool's own --short.
      #: (Hash[Array[String], Array[String]], ?last: Array[String]) -> void
      def initialize(groups, last: [])
        @groups = groups
        @last = last
        freeze
      end

      NONE = new({}) #: AcknowledgementsOffered

      # The members an acknowledgement takes in for principle id.
      #: (String) -> Array[String]
      def members_of(id) = @groups.select { |ids, _| ids.include?(id) }.values.flatten

      # Each acknowledgement's command, filled and shell-quoted so the agent types no id, through invocation; a set
      # holding a member in last after a line asking to acknowledge it last, since its check exits as --short does
      # while it lists a member the answer leaves out.
      #: (Invocation) -> Array[String]
      def lines(invocation)
        @groups.flat_map do |ids, members|
          line = invocation.listed_in_project("start-audit", ids, options: members.flat_map { ["--member", it] })
          own = members & @last
          own.empty? ? [line] : [last_line(own), line]
        end
      end

      private

      # The line asking to acknowledge own, members whose check is this tool's own --short, after the others.
      #: (Array[String]) -> String
      def last_line(own)
        "Acknowledge #{ProseList.new(own.map { ShellWord.new(it).to_s })} last: its check, list-member-problems " \
          "--short, exits #{ProblemLines::CHANGED} while it lists a member this acknowledgement leaves out, so first " \
          "acknowledge or audit, and commit, each member listed that it leaves out."
      end
    end
  end
end

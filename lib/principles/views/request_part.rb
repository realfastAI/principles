# typed: strict
# frozen_string_literal: true

require_relative "instruction"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One part of a judgement request beyond its members, such as the prior findings to decide or the members
    # to check against the activation: what the agent reads of it, its list and the instruction for it, and
    # the slots it adds to the answer's template, which the request builds in where each belongs.
    class RequestPart
      # The slots this part adds to the answer's template.
      #: Hash[String, untyped]
      attr_reader :slots
      # The instructions for deciding this part, each printed after its list.
      #: Array[Instruction]
      attr_reader :instructions

      # listed is what the agent reads of this part before its instructions. help is, by slot, the placeholder text
      # each of its entries carries in the answer printed alone, where no instruction is printed beside it to say
      # what each field takes. alone is, by slot, its entries as the answer printed alone gives them before their
      # help, where they show what the list beside the request's answer would.
      #: (shown: Hash[String, untyped], slots: Hash[String, untyped], ?instructions: Array[Instruction],
      #|  ?help: Hash[String, Hash[String, untyped]], ?alone: Hash[String, untyped]) -> void
      def initialize(shown:, slots:, instructions: [], help: {}, alone: {})
        @listed = shown
        @slots = slots
        @instructions = instructions
        @help = help
        @alone = alone
        freeze
      end

      # What the agent reads of this part: its list, then each instruction as the request prints it.
      #: () -> Hash[String, untyped]
      def shown = @instructions.reduce(@listed) { |all, instruction| all.merge(instruction.printed) }

      # Why the index gives no bytes for this part, when this read left it unfilled; nil, as here, when it is filled.
      #: () -> String?
      def bytes_unknown = nil

      # The slots, each entry with its help in place of the fields the agent fills.
      #: () -> Hash[String, untyped]
      def slots_to_fill
        @slots.to_h do |name, entries|
          [name, @alone.fetch(name, entries).map { |entry| entry.merge(@help.fetch(name, {})) }]
        end
      end
    end
  end
end

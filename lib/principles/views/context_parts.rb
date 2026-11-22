# typed: strict
# frozen_string_literal: true

require_relative "../prose_list"
require_relative "member_lines_beside_text"
require_relative "printed_json"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The parts of a full audit's request that start-audit --part prints alone, by name, from the request's context:
    # each key but the members and the instruction fields, each member alone, and each instruction field as the
    # request prints it, in part where it trims one, which --instruction prints whole; and the index of them all.
    class ContextParts
      # What starts a member's part name, keeping member ids apart from the context's keys.
      MEMBER = "members/" #: String

      # The part that lists every other part, so the agent sizes its reads before it makes them.
      INDEX = "index" #: String

      # The part holding the answer to fill, as the request prints it beside its context.
      TEMPLATE = "response_template" #: String

      # instruction_fields is each field the context prints an instruction under, in order. template is the answer to
      # fill, as the request prints it. texts is each member's lines now, by id, one string each, which its part
      # prints and the whole request does not. optional names each part the context lists only when it holds something.
      #: (Hash[String, untyped], instruction_fields: Array[String], template: Hash[String, untyped],
      #|  ?texts: Hash[String, Array[String]], ?optional: Array[String]) -> void
      def initialize(context, instruction_fields:, template:, texts: {}, optional: [])
        @context = context
        @instruction_fields = instruction_fields
        @template = template
        @texts = texts
        @optional = optional
        freeze
      end

      # Each part's name, in the order the context prints it, then each member's as members/ID, in the request's order,
      # then each instruction field, in the order the context prints them, and last the answer to fill.
      #: () -> Array[String]
      def names
        [*(@context.keys - ["members", *@instruction_fields]), *members.map { "#{MEMBER}#{it.fetch("id")}" },
         *@instruction_fields, TEMPLATE]
      end

      # Each name --part prints: the index, then each part it lists.
      #: () -> Array[String]
      def printable = [INDEX, *names]

      # Each optional part the context leaves out, holding nothing for this request, which --part prints as empty.
      #: () -> Array[String]
      def left_out = @optional - @context.keys

      # Each part's name, as names lists it, with the bytes --part prints of its value.
      #: () -> Hash[String, Integer]
      def part_bytes = names.to_h { [it, bytes(shown(it))] }

      # The part name, under its key, as the context prints it; a member's entry alone under members, with its text
      # when given, its id read after the one prefix, so an id with a slash, or starting members/, is read whole.
      #: (String) -> Hash[String, untyped]
      def shown(name)
        return { INDEX => index } if name == INDEX
        return empty([name]) if left_out.include?(name)
        return @template if name == TEMPLATE
        return { name => @context.fetch(name) } unless name.start_with?(MEMBER)

        id = name.delete_prefix(MEMBER)
        { "members" => members.select { it.fetch("id") == id }.map { with_text(it) } }
      end

      # The parts names, each as shown prints it, printed together: each member's in one members list and each empty
      # one named in one part_empty, in the order given, where merging the parts one by one leaves the last alone.
      #: (Array[String]) -> Hash[String, untyped]
      def shown_together(names)
        together = names.reduce({}) { |all, name| all.merge(shown(name)) } #: Hash[String, untyped]
        with_every_empty(with_every_member(together, names), names)
      end

      private

      # together with each member names names in one members list; together as it is when names name no member.
      #: (Hash[String, untyped], Array[String]) -> Hash[String, untyped]
      def with_every_member(together, names)
        return together unless together.key?("members")

        together.merge("members" => names.flat_map { shown(it).fetch("members", []) })
      end

      # together with one part_empty naming every empty part names; together as it is when names name none.
      #: (Hash[String, untyped], Array[String]) -> Hash[String, untyped]
      def with_every_empty(together, names)
        empty_named = names & left_out
        empty_named.empty? ? together : together.merge(empty(empty_named))
      end

      # What --part prints for the optional parts names, which the request leaves out for holding nothing, naming each
      # in the order given, so the agent knows which of the parts it asked for were empty.
      #: (Array[String]) -> Hash[String, String]
      def empty(names)
        { "part_empty" => "Nothing to list for #{ProseList.new(names)} in this request; " \
                          "the answer needs nothing for #{names.one? ? "it" : "them"}." }
      end

      # Each part with the bytes --part prints of its value, and each member with whether this audit judges it, and
      # why when the request says, or carries its last assessment forward.
      #: () -> Array[Hash[String, untyped]]
      def index
        part_bytes.map do |name, size|
          entry = { "part" => name, "bytes" => size }
          name.start_with?(MEMBER) ? entry.merge(judged(shown(name).fetch("members").fetch(0))) : entry
        end
      end

      # How many bytes value prints as, as this tool prints a result.
      #: (Hash[String, untyped]) -> Integer
      def bytes(value) = PrintedJson.bytes(value)

      # member as the request lists it, with its text when given, and then its acknowledged lines now pointing at
      # that text, so the part prints each line now once.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def with_text(member)
        text = @texts[member.fetch("id")] or return member
        since = member["acknowledged_since_last_audit"]
        return member.merge("text" => text) unless since

        lines = MemberLinesBesideText.new(since.fetch("member_lines")).shown
        member.merge("acknowledged_since_last_audit" => since.merge("member_lines" => lines), "text" => text)
      end

      # What this audit does with member: carries its last assessment forward, or judges it, with why when given.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def judged(member)
        return { "this_audit" => "carries_forward" } if member["carried_forward"]

        { "this_audit" => "judges", **member.slice("judge_because") }
      end

      # The members the request lists, each as it prints it.
      #: () -> Array[Hash[String, untyped]]
      def members = @context.fetch("members")
    end
  end
end

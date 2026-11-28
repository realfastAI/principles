# typed: strict
# frozen_string_literal: true

require_relative "../prose_list"
require_relative "invocation"
require_relative "member_lines_beside_text"
require_relative "printed_json"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The parts of a full audit's request that start-audit --part prints alone, by name, from the request's context:
    # each key but the members and the instruction fields, each member alone, and each instruction field as the
    # request prints it, in part where it trims one, which --instruction prints whole; and the index of them all.
    class ContextParts
      # What starts a member's part name, keeping member ids apart from the context's keys.
      MEMBER = "members/" #: String

      # What starts the name of a part holding one member's text alone, apart from its member part.
      TEXT = "member_text/" #: String

      # The part that lists every other part, so the agent sizes its reads before it makes them.
      INDEX = "index" #: String

      # The part listing the id of each member this audit judges, one a line, for the agent to read their parts by.
      JUDGED = "judged_members" #: String

      # The part holding the answer to fill, as the request prints it beside its context.
      TEMPLATE = "response_template" #: String

      # Each member's lines now, by id, one string each, as the request's parts print them and the whole request does
      # not: in the member's part, or, for each member apart names, in a part of its own.
      class MemberTexts
        #: (Hash[String, Array[String]], ?apart: TextsApart?) -> void
        def initialize(lines, apart: nil)
          @lines = lines
          @apart = apart
          freeze
        end

        # The id of each member whose text prints in a part of its own.
        #: () -> Array[String]
        def apart = @apart&.ids || []

        # The lines the part of the member id prints, or nil when none are given for it.
        #: (String) -> Array[String]?
        def beside(id) = @lines[id]

        # The lines of the member id, as its own text part prints them.
        #: (String) -> Array[String]
        def of(id) = @lines.fetch(id)

        # How the member part of id names its text part, which prints in bytes, or nil when its text prints in its
        # member part.
        #: (String) { () -> Integer } -> Hash[String, untyped]?
        def text_part(id, &) = @apart&.text_part(id, &)
      end

      # The members whose text prints in a part of its own in the full audit of principle_id, each part printed by a
      # command as invocation runs it, and when the request says to read each of them whole, by id, in read_whole:
      # "judged", as a step of judging it, or "flagged", if a carried member a fact fires on is judged again.
      class TextsApart
        #: (Array[String], Invocation, principle_id: String, ?read_whole: Hash[String, String]) -> void
        def initialize(ids, invocation, principle_id:, read_whole: {})
          @ids = ids
          @invocation = invocation
          @principle_id = principle_id
          @read_whole = read_whole
          freeze
        end

        # The id of each member whose text prints in a part of its own.
        #: Array[String]
        attr_reader :ids

        # How the member part of id names its text part, which prints in the bytes the block gives: the command that
        # prints it, and, when the request says to, when to read it whole; nil when its text is not apart.
        #: (String) { () -> Integer } -> Hash[String, untyped]?
        def text_part(id, &bytes)
          return unless @ids.include?(id)

          named = { "read_with" => @invocation.in_project("start-audit", @principle_id,
                                                          options: ["--part", "#{TEXT}#{id}"]), "bytes" => bytes.call }
          when_read = @read_whole[id] or return named

          named.merge("read_whole" => read_whole(when_read))
        end

        private

        # The prompt saying when to read a text part whole, by when_read, as read_whole gives it.
        #: (String) -> String
        def read_whole(when_read)
          return Prompts.text("assess-every-member/read-a-flagged-member-s-text-whole") if when_read == "flagged"

          Prompts.text("assess-every-member/read-a-judged-member-s-text-whole")
        end
      end

      # instruction_fields is each field the context prints an instruction under, in order. template is the answer to
      # fill, as the request prints it. texts is each member's lines now, as its parts print them. optional names each
      # part the context lists only when it holds something.
      #: (Hash[String, untyped], instruction_fields: Array[String], template: Hash[String, untyped],
      #|  ?texts: MemberTexts, ?optional: Array[String]) -> void
      def initialize(context, instruction_fields:, template:, texts: MemberTexts.new({}), optional: [])
        @context = context
        @instruction_fields = instruction_fields
        @template = template
        @texts = texts
        @optional = optional
        freeze
      end

      # Each part's name, in the order the context prints it, then each member's as members/ID, in the request's order,
      # then each text printed apart as member_text/ID, then each instruction field, in the order the context prints
      # them, and last the answer to fill.
      #: () -> Array[String]
      def names
        [*(@context.keys - ["members", *@instruction_fields]), *members.map { "#{MEMBER}#{it.fetch("id")}" },
         *@texts.apart.map { "#{TEXT}#{it}" }, *@instruction_fields, TEMPLATE]
      end

      # Each name --part prints: the index and the judged members' ids, then each part the index lists.
      #: () -> Array[String]
      def printable = [INDEX, JUDGED, *names]

      # Each optional part the context leaves out, holding nothing for this request, which --part prints as empty.
      #: () -> Array[String]
      def left_out = @optional - @context.keys

      # Each part's name, as names lists it, with the bytes --part prints of its value.
      #: () -> Hash[String, Integer]
      def part_bytes = names.to_h { [it, bytes(shown(it))] }

      # The part name: a listing of the other parts, or one of them as from_context prints it.
      #: (String) -> Hash[String, untyped]
      def shown(name) = listing(name) || from_context(name)

      # The parts names, each as shown prints it, printed together: each member's in one members list and each empty
      # one named in one part_empty, in the order given, where merging the parts one by one leaves the last alone.
      #: (Array[String]) -> Hash[String, untyped]
      def shown_together(names)
        together = names.reduce({}) { |all, name| all.merge(shown(name)) } #: Hash[String, untyped]
        with_every_empty(with_every_member(together, names), names)
      end

      private

      # The part name, under its key, as the context prints it; a member's entry alone under members, with its text
      # when given, its id read after the one prefix, so an id with a slash, or starting members/, is read whole.
      #: (String) -> Hash[String, untyped]
      def from_context(name)
        return empty([name]) if left_out.include?(name)
        return @template if name == TEMPLATE
        return text_part(name.delete_prefix(TEXT)) if name.start_with?(TEXT)
        return { name => @context.fetch(name) } unless name.start_with?(MEMBER)

        member_part(name.delete_prefix(MEMBER))
      end

      # together with each member names names in one members list, and each text in one member_texts list; together
      # as it is when names name neither.
      #: (Hash[String, untyped], Array[String]) -> Hash[String, untyped]
      def with_every_member(together, names)
        %w[members member_texts].select { together.key?(it) }.reduce(together) do |all, list|
          all.merge(list => names.flat_map { shown(it).fetch(list, []) })
        end
      end

      # The text of the member id alone, apart from its member part.
      #: (String) -> Hash[String, untyped]
      def text_part(id) = { "member_texts" => [{ "id" => id, "text" => @texts.of(id) }] }

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

      # The part name when it lists the other parts, as the index does, or the members this audit judges; nil for any
      # other part.
      #: (String) -> Hash[String, untyped]?
      def listing(name)
        if name == INDEX then { INDEX => index }
        elsif name == JUDGED then { JUDGED => members.reject { it["carried_forward"] }.map { it.fetch("id") } }
        end
      end

      # How many bytes value prints as, as this tool prints a result.
      #: (Hash[String, untyped]) -> Integer
      def bytes(value) = PrintedJson.bytes(value)

      # The part of the member id: its entry alone under members, as with_text prints it.
      #: (String) -> Hash[String, untyped]
      def member_part(id) = { "members" => members.select { it.fetch("id") == id }.map { with_text(it) } }

      # member as the request lists it, with its text when given, and then its acknowledged lines now pointing at
      # that text, so the part prints each line now once; or, when its text prints apart, with how to read that part
      # and its bytes in place of the text.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def with_text(member)
        id = member.fetch("id")
        named = @texts.text_part(id) { bytes(text_part(id)) }
        return member.merge("text_part" => named) if named

        text = @texts.beside(id) or return member
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

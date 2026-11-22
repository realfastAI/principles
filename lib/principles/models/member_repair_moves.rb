# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The moves that may repair a member this tool cannot find, each as the locator fields it keeps and those the agent
    # fills in, which Views::MemberRepairs prints as move-member commands. A member whose file is gone moves to the
    # path the agent finds, keeping its own section, passage or query, so a rename keeps its audit; so does one whose
    # file git tracks only under another spelling, moved to that spelling when its refusal names it, which the agent
    # checks first. A member whose place in its file is gone moves within it, or into another file its text moved to; a
    # passage keeps its anchors, so a move cannot silently widen it to its whole new section, but not an opening or
    # ending text that is gone, which a move repeating it would fail on again as printed; and it is given no section a
    # passage located by its opening alone never had. Which fits is the agent's to judge.
    class MemberRepairMoves
      # The locator fields a member may give beside its path.
      LOCATOR = %w[section starting_at ending_at query].freeze #: Array[String]
      # The passage anchor each refusal code says is no longer in its file, which a move fills in afresh.
      LOST_ANCHOR = { "passage_not_found" => %w[starting_at],
                      "passage_end_not_found" => %w[ending_at] }.freeze #: Hash[String, Array[String]]
      # The refusal codes that say a member's file is not at its path, though its text may be unchanged: gone, or
      # tracked by git only under another spelling.
      FILE_NOT_AT_PATH = %w[unreadable_file renamed_in_case].freeze #: Array[String]

      # One move: the locator fields it keeps, by name, and those the agent fills in.
      class Move
        #: Hash[String, untyped]
        attr_reader :keep

        #: Array[String]
        attr_reader :fill

        #: (Hash[String, untyped], Array[String]) -> void
        def initialize(keep, fill)
          @keep = keep
          @fill = fill
          freeze
        end
      end

      # member is the member's locator fields, as its map holds them; code is that of the refusal saying why it cannot
      # be found, and tracked_as the spelling git tracks its path under, which a renamed_in_case refusal gives.
      #: (Hash[String, untyped], code: String?, ?tracked_as: String?) -> void
      def initialize(member, code:, tracked_as: nil)
        @member = given(member, LOCATOR) #: Hash[String, untyped]
        @code = code
        @tracked_as = tracked_as
        freeze
      end

      # Each move that may repair the member.
      #: () -> Array[Move]
      def to_a
        return [move(@member.merge("path" => @tracked_as), [])] if @code == "renamed_in_case" && @tracked_as
        return [move(@member, %w[path])] if FILE_NOT_AT_PATH.include?(@code)
        return [move({}, %w[query])] if @member["query"]

        lost = LOST_ANCHOR.fetch(@code.to_s, [])
        anchors = given(@member, %w[starting_at ending_at] - lost)
        section = @member.key?("section") ? %w[section] : []
        [move(anchors, [*lost, *section]), move(anchors, [*lost, "path", *section])]
      end

      private

      # The fields of member named in fields that it gives, in the order fields names them.
      #: (Hash[String, untyped], Array[String]) -> Hash[String, untyped]
      def given(member, fields) = fields.filter_map { [it, member[it]] unless member[it].nil? }.to_h.freeze

      #: (Hash[String, untyped], Array[String]) -> Move
      def move(keep, fill) = Move.new(keep, fill)
    end
  end
end

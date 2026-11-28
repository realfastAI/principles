# typed: strict
# frozen_string_literal: true

require_relative "../prose_list"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What add-member's result says of the members sharing a line with the member it added, show-principle
    # beside each member it shows, and a full audit's request beside each member, of other maps only:
    # those in its map (overlaps), those of them spanning exactly its lines
    # (same_lines_as), and those in other maps, with their roles there and same_lines when they span exactly
    # its lines, spans_these_lines when their lines include all of its and within_these_lines when its lines
    # include theirs (mapped_elsewhere). Each field is printed only when there are some; add-member
    # also prints the sentences that say what it means for the agent.
    class LinesSharedWithMember
      # Why the agent checks the text where the lines meet, unless each member holding another's lines is a whole
      # file, which holds every line's text.
      TEXT_CHECK = "Lines are not text: where two share a first or last line, a passage can start or end partway " \
                   "through it, so check the text there before deciding which edit reaches which member. " #: String

      # What an edit to this member reaches when one of them spans all of its lines.
      SPANNING = "Every edit to this member's text is an edit to each marked spans_these_lines too. " #: String
      # What an edit to one of them reaches when it lies within this member's lines.
      WITHIN = "Every edit to the text of each marked within_these_lines is an edit to this member's too. " #: String

      # text_check says whether a member holding another's lines is not a whole file, so the text needs checking.
      #: (?overlaps: Array[String], ?same_lines_as: Array[String], ?mapped_elsewhere: Array[Hash[String, untyped]],
      #|  ?text_check: bool) -> void
      def initialize(overlaps: [], same_lines_as: [], mapped_elsewhere: [], text_check: false)
        @overlaps = overlaps
        @same_lines_as = same_lines_as
        @mapped_elsewhere = mapped_elsewhere
        @text_check = text_check
        freeze
      end

      # The fields to merge into added, each only when there are some.
      #: () -> Hash[String, untyped]
      def to_h
        { "overlaps" => @overlaps, "same_lines_as" => @same_lines_as, "mapped_elsewhere" => @mapped_elsewhere }
          .reject { |_field, shared| shared.empty? }
      end

      # The sentences the question carries for them, or none.
      #: () -> String
      def note
        "#{overlap_note}#{elsewhere_note}#{same_lines_note}"
      end

      private

      #: () -> String
      def overlap_note
        return "" if @overlaps.empty?

        "It shares lines with #{@overlaps.join(", ")}, so one edit there will show as a change to each. "
      end

      #: () -> String
      def elsewhere_note
        return "" if @mapped_elsewhere.empty?

        "Members of other principles share lines with this one (mapped_elsewhere), so an edit to the lines they " \
          "share changes each. #{spans_note}Check that this member's role fits beside the roles they give it there. "
      end

      # What an edit reaches where some of them are marked spans_these_lines or within_these_lines, said once by the
      # mark, since mapped_elsewhere names each; one sentence per entry made a whole-file member's result 9.4 KB.
      # Lines are not text, so the agent checks where they share a first or last line.
      #: () -> String
      def spans_note
        spans = marked?("spans_these_lines")
        within = marked?("within_these_lines")
        return "" unless spans || within

        "#{SPANNING if spans}#{WITHIN if within}An edit outside the shared lines reaches only the member it is in. " \
          "#{TEXT_CHECK if @text_check}"
      end

      # Whether any of them carries this mark.
      #: (String) -> bool
      def marked?(mark) = @mapped_elsewhere.any? { |each| each[mark] }

      # Equal lines are not equal text, as a passage can end within its last line, so the agent decides.
      #: () -> String
      def same_lines_note
        return "" if @same_lines_as.empty? && @mapped_elsewhere.none? { |each| each["same_lines"] }

        named = same_lines_named
        "#{ProseList.new(named)} #{named.length > 1 ? "span" : "spans"} exactly these lines " \
          "(same_lines), under another id. If they are meant to be one member, decide which to keep; if both are " \
          "meant, say why in this member's role. "
      end

      # Each member spanning exactly these lines, by id, with its principle when it is in another.
      #: () -> Array[String]
      def same_lines_named
        elsewhere = @mapped_elsewhere.select { |each| each["same_lines"] }
        @same_lines_as.map { |id| "`#{id}`" } +
          elsewhere.map { |each| "`#{each.fetch("member_id")}` in #{each.fetch("principle_id")}" }
      end
    end
  end
end

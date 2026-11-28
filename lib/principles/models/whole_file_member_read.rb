# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # How a full audit's request prints a whole-file member's text: in a part of its own, which the index lists and
    # sizes, so a member's part does not print tens of kilobytes beside its metadata. A member the audit judges is
    # read whole from that part, as a stated step of the judgement, since no diff shows a line a change elsewhere
    # left stale, and so is a carried member a fact fires on, if the agent judges it again. A member judged for its
    # text changing shows its changed lines beside that step: an acknowledged one in its acknowledged lines, any
    # other in changed_lines. A passage keeps its text in its member part.
    class WholeFileMemberRead
      # whole_file says whether the member is a whole file; listed is the member as the request lists it, with
      # carried_forward and flagged when its last assessment is carried, or judge_because when it is judged again.
      #: (whole_file: bool, listed: Hash[String, untyped]) -> void
      def initialize(whole_file:, listed:)
        @whole_file = whole_file
        @listed = listed
        freeze
      end

      # Whether the member's text prints in a part of its own rather than in its member part.
      #: () -> bool
      def text_apart? = @whole_file

      # When the request says to read that part whole: "judged", as a step of judging the member, or "flagged", for a
      # carried member a fact fires on, if the agent judges it again; nil when it does not say to.
      #: () -> String?
      def read_whole
        return unless @whole_file
        return "judged" unless carried?

        "flagged" if @listed["flagged"]
      end

      # Whether its part shows its changed lines since the last full audit: its text changed and no acknowledgement
      # shows the change.
      #: () -> bool
      def changed_lines? = @whole_file && @listed["judge_because"] == "text_changed"

      private

      #: () -> bool
      def carried? = !@listed["carried_forward"].nil?
    end
  end
end

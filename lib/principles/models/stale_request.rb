# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "request_id"
require_relative "map_change"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The refusal of an answer to one principle's audit request that no longer matches the project: its cause, the
    # members changed since the request's base commit when any are known, or how its map changed since then, or else
    # every input the request depends on, and its repair: to answer the audit's open correction when members alone
    # changed, or else to start again.
    class StaleRequest
      # principle_id is the principle audited; changed names the members whose text differs from the base commit's;
      # correction_open says whether the principle's record is open, its correction asked for and not yet answered;
      # map_change is how the map differs from the one the request was printed from, when that is known.
      #: (String, ?Array[String], ?correction_open: bool, ?map_change: MapChange?) -> void
      def initialize(principle_id, changed = [], correction_open: false, map_change: nil)
        @principle_id = principle_id
        @changed = changed
        @correction_open = correction_open
        @map_change = map_change
        freeze
      end

      #: () -> Error
      def refusal
        Error.new("stale_request", "This request no longer matches #{@principle_id}: #{cause}", repair)
      end

      private

      # The members changed since the base commit, which a request is printed only once they are committed; or else
      # how its map changed since then; otherwise every input that may have changed.
      #: () -> String
      def cause
        unless @changed.empty?
          return "#{ProseList.new(@changed)} #{@changed.one? ? "has" : "have"} changed since its base commit"
        end
        return "its map has changed since its base commit: #{@map_change}" if @map_change

        "its map, a member, the commit it was based on, or what says when a listed member loads and how big it is " \
          "(project settings, frontmatter or a listed file), has changed since it was printed, or another release " \
          "or checkout of principles printed it"
      end

      # To start the audit again; but while its correction is open and only members changed, that correction stays
      # answerable, since it is checked against the members at the base commit, so the repair names the command that
      # prints its answer again from the open record; and after a map change alone, the answer stays worth keeping.
      #: () -> String
      def repair
        start = "#{Error::EXECUTABLE} start-audit #{@principle_id}"
        return carried_over(start, @map_change) if @map_change && @changed.empty?
        return "Start the audit again and answer the new request: #{start}" unless @correction_open && @changed.any?

        "This audit's correction is still open, and fixing members leaves it current: answer it rather than start " \
          "again, saving its answer from this command's output, filling only its dispositions, and submitting it: " \
          "#{Error::EXECUTABLE} show-open-correction #{@principle_id}"
      end

      # To carry the answer to a new request, judging again what map_change touched, or to undo map_change.
      #: (String, MapChange) -> String
      def carried_over(start, map_change)
        "Keep this answer. To carry it to a new request, copy that request's request_id and basis into it, judge " \
          "#{map_change.to_judge_again}, and submit it; or change the map back as it was at the base commit, " \
          "commit it, and submit this answer unchanged.\nStart the new request: #{start}"
      end
    end
  end
end

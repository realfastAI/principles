# typed: strict
# frozen_string_literal: true

require "json"
require_relative "candidate_outline"
require_relative "entry_files"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # How much list-candidate-files may print: its listed files' outlines, cut a whole file's list items at a time
    # until the result fits. One user's run printed 66,145 B for 45 files, against a ceiling of about
    # 37 KB, and no cap on items under each heading both fitted and kept a core list of 8 whole.
    class OutlineBudget
      # The most bytes the result may print, under the host's inline limit for a tool result. Claude Code's tools
      # reference, "Output limits" (code.claude.com/docs/en/tools-reference, checked 2026-11-16), gives a Bash result
      # inline "up to roughly 30,000 characters by default; past that, the path of a file" and a 2,000-character
      # preview. One user's 40.4 KB result arrived that way, and its agent scripted over the saved file.
      # A character is at least a byte, so 28,000 B stays under 30,000 characters with room.
      BYTES = 28_000

      # The fields of a file's entry its outline gives, which a cut replaces.
      OUTLINE_FIELDS = %w[description opening_line outline].freeze

      # The lists naming the files cut: those whose outline's lines were cut, and those whose whole outline was.
      NAMING_LISTS = %w[outlines_cut outlines_left_out].freeze

      # Each outlined file's outline, by path.
      #: (Hash[String, CandidateOutline]) -> void
      def initialize(outlines)
        @outlines = outlines
        freeze
      end

      # The listing with its files' outlines cut, one cut of one file at a time in cut order, until what the block says
      # it prints fits BYTES, each file whose items were cut named under outlines_cut. If every cut is made and it
      # still does not fit, every file cut is named, and range_outlines_bytes gives what the outlines of the files a
      # range changed print, when there are any: they are never left out, and which to drop is the agent's call.
      #: (Hash[String, untyped]) { (Hash[String, untyped]) -> Integer } -> Hash[String, untyped]
      def cut(listing, &printed_bytes)
        shortest = cut_order(listing).reduce(listing) do |shorter, (path, cuts)|
          return shorter if printed_bytes.call(shorter) <= BYTES

          cut_file(shorter, path, cuts)
        end
        printed_bytes.call(shortest) <= BYTES ? shortest : past_budget(shortest)
      end

      private

      # The listing every cut left past BYTES, naming what its range's outlines print, when it lists any.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def past_budget(listing)
        range = listing.fetch("files").select { |file| file["changed_in_range"] }
        return listing if range.empty?

        bytes = range.sum { |file| JSON.generate(file.slice(*OUTLINE_FIELDS)).bytesize }
        bytes > BYTES ? listing.merge("range_outlines_bytes" => bytes) : listing
      end

      # Each cut that shortens a file, as its path and how many of CandidateOutline::CUTS it then has made. Every file
      # but the root entry files and those marked changed_in_range comes first; then the changed files, which a survey
      # of a change is about; last the entry files, since a host loads those in every session, so they keep
      # theirs longest, in EntryFiles' order. Within each group, each cut is made across the files in CUTS' order:
      # those with a description first, since the agent still reads what each is for, then the deepest path, then the
      # most bytes the cut saves.
      #: (Hash[String, untyped]) -> Array[[String, Integer]]
      def cut_order(listing)
        outlined = listing.fetch("files").select { |file| @outlines.key?(file.fetch("path")) }
        outlined.group_by { |file| kept_rank(file) }.sort.flat_map do |rank, files|
          (1..most_cuts(rank)).flat_map { |cuts| cuts_across(files, cuts) }
        end
      end

      # How many of CUTS are made on a file of this rank: on a changed or entry file every one but leaving its outline
      # out.
      #: (Integer) -> Integer
      def most_cuts(rank) = rank.zero? ? CandidateOutline::CUTS.length : CandidateOutline::ENTRY_FILE_CUTS

      # The files the cuts'th cut shortens, in the order it is made across them.
      #: (Array[Hash[String, untyped]], Integer) -> Array[[String, Integer]]
      def cuts_across(files, cuts)
        files.select { |file| saved(file.fetch("path"), cuts).positive? }
             .sort_by { |file| cut_rank(file, cuts) }.map { |file| [file.fetch("path"), cuts] }
      end

      # Where a file comes among those one cut shortens: described or not, depth, bytes saved, then path.
      #: (Hash[String, untyped], Integer) -> [Integer, Integer, Integer, String]
      def cut_rank(file, cuts)
        path = file.fetch("path")
        [file.key?("description") ? 0 : 1, -path.count("/"), -saved(path, cuts), path]
      end

      # 0 for a file that is neither a root entry file nor changed in the range, 1 for a changed one, then each entry
      # file in EntryFiles::PATHS reversed, so the first, CLAUDE.md, keeps its items longest.
      #: (Hash[String, untyped]) -> Integer
      def kept_rank(file)
        index = EntryFiles::PATHS.index(file.fetch("path"))
        return 1 + EntryFiles::PATHS.length - index if index

        file["changed_in_range"] ? 1 : 0
      end

      # The bytes the cuts'th cut of path's outline saves over the cuts made before it.
      #: (String, Integer) -> Integer
      def saved(path, cuts)
        outline = @outlines.fetch(path)
        JSON.generate(outline.to_h(cuts: cuts - 1)).bytesize - JSON.generate(outline.to_h(cuts:)).bytesize
      end

      # The listing with path's outline cut to its first `cuts` cuts, and the file named as its cuts say.
      #: (Hash[String, untyped], String, Integer) -> Hash[String, untyped]
      def cut_file(listing, path, cuts)
        outline = @outlines.fetch(path)
        files = listing.fetch("files").map do |file|
          file.fetch("path") == path ? file.except(*OUTLINE_FIELDS).merge(outline.to_h(cuts:)) : file
        end
        named(listing.merge("files" => files), path, outline, cuts)
      end

      # The listing naming path under outlines_cut once its outline's lines are cut, and under outlines_left_out instead
      # once its whole outline is; a cut description says so in its own text. A list that names no path is left out.
      #: (Hash[String, untyped], String, CandidateOutline, Integer) -> Hash[String, untyped]
      def named(listing, path, outline, cuts)
        named_in = naming_list(outline, cuts)
        lists = NAMING_LISTS.to_h do |list|
          [list, listing.fetch(list, []) - [path] + (list == named_in ? [path] : [])]
        end
        listing.except(*NAMING_LISTS).merge(lists.reject { |_, paths| paths.empty? })
      end

      # The one of NAMING_LISTS a file with these cuts made belongs in, the whole outline left out moving it from the
      # first to the second; nil while only its description is cut.
      #: (CandidateOutline, Integer) -> String?
      def naming_list(outline, cuts)
        return "outlines_left_out" if outline.left_out?(cuts)

        "outlines_cut" if outline.outline_cut?(cuts)
      end
    end
  end
end

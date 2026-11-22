# typed: strict
# frozen_string_literal: true

require_relative "../data/project_files"
require_relative "candidate_files"
require_relative "ignored_candidates"
require_relative "outline_budget"
require_relative "project_history"
require_relative "survey_search_paths"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What list-candidate-files found: the inventory of candidate files as it lists them, and in git
    # which of them, or of the files their links lead to, git does not track. Each list that names a file is
    # something the agent asks the project's owner about before mapping, and only those are asked, since asks for
    # empty lists hid the one that applied.
    class CandidateInventory
      # The lists the agent asks the owner about, in the order the asks are put.
      OWNER_ASK_KEYS = %w[possibly_test_data untracked ignored ignored_folders].freeze

      # The most paths an ask names inline: a short list can be pasted to the owner as it stands, while a
      # longer one would bury the ask, so the agent reads it from its list instead.
      NAMED_INLINE_AT_MOST = 3

      # What list-candidate-files finds in the project's files, each listed file's text read from them. After a commit,
      # a full sha, the files its range changed come first, the Markdown ones outside the places hosts load listed too.
      # The Markdown files not yet committed are named apart then, under uncommitted, since no commit in the
      # range holds them.
      #: (Data::ProjectFiles, ProjectHistory, search_paths: SurveySearchPaths, ?after: String?,
      #|  ?mapped: Array[String]) -> CandidateInventory
      def self.read(files, history, search_paths:, after: nil, mapped: [])
        changed = after ? history.changed_after(after) : []
        inventory = files.inventory(also: changed.grep(CandidateFiles::MARKDOWN) | (changed & mapped),
                                    matching: search_paths.globs, conventional: search_paths.conventional?)
        inventory = inventory.merge(search_paths.recorded_listing)
        inventory = inventory.merge("uncommitted" => uncommitted_markdown(history)) if after
        found(inventory, history, changed:, conventional: search_paths.conventional?) { |path| files.read_text(path) }
      end

      # An explicit file request uses the survey's entries and budget without its broad search.
      #: (Data::ProjectFiles, ProjectHistory, paths: Array[String]) -> CandidateInventory
      def self.requested(files, history, paths:)
        found(files.requested_inventory(paths), history) { |path| files.read_text(path) }
      end

      # The Markdown files that differ from HEAD or are untracked, ignored ones aside.
      #: (ProjectHistory) -> Array[String]
      def self.uncommitted_markdown(history) = (history.uncommitted_outside([]) || []).grep(CandidateFiles::MARKDOWN)
      private_class_method :uncommitted_markdown

      # What the project's inventory lists, and which listed files, or files their links lead to, history says
      # git does not track.
      # Each listed file's text, which its outline is read from, is what the block gives for its path.
      # changed names the files a range of commits changed, which list first, marked.
      #: (Hash[String, untyped], ProjectHistory, ?changed: Array[String], ?conventional: bool) { (String) -> String }
      #|  -> CandidateInventory
      def self.found(inventory, history, changed: [], conventional: true, &text_of)
        texts = {} #: Hash[String, String]
        files = CandidateFiles.new(inventory.fetch("files"), selected: inventory.fetch("selected_files", []),
                                                             text_of: ->(path) { texts[path] ||= text_of.call(path) })
        hints = inventory.fetch("possibly_test_data")
        listed = listed(inventory, files.listing(hints, changed:))
        new(listed, untracked: history.untracked_excluding_ignored(listed.fetch("files").map { it.fetch("path") }),
                    outlines: files.outlines(hints), conventional:)
      end

      # The inventory as list-candidate-files lists it: the instruction files agent hosts load by convention, the other
      # files counted by directory, the listed files that look like test data, and in git the ignored ones, unread, each
      # folder git ignores counted once.
      #: (Hash[String, untyped], Hash[String, untyped]) -> Hash[String, untyped]
      def self.listed(inventory, files_listing)
        listed = inventory.except("ignored", "ignored_ancestor_folders", "selected_files").merge(files_listing)
        return listed unless inventory.key?("ignored")

        listed.merge(IgnoredCandidates.new(paths: inventory.fetch("ignored"),
                                           folders: inventory.fetch("ignored_ancestor_folders")).listing)
      end
      private_class_method :listed

      # The listing, as list-candidate-files prints it.
      #: Hash[String, untyped]
      attr_reader :listing

      # The listed files, and the files their links lead to, git does not track; nil outside git, where nothing
      # checked them.
      #: Array[String]?
      attr_reader :untracked

      # outlines holds each outlined file's outline, by path, which within_budget cuts by.
      #: (Hash[String, untyped], untracked: Array[String]?, ?outlines: Hash[String, CandidateOutline],
      #|  ?conventional: bool) -> void
      def initialize(listing, untracked:, outlines: {}, conventional: true)
        @listing = listing
        @untracked = untracked
        @outlines = outlines
        @conventional = conventional
        @lists = listing.merge("untracked" => untracked) #: Hash[String, untyped]
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h = @listing

      # Whether the survey looked in the places hosts load by convention, as it does unless --only narrowed it.
      #: () -> bool
      def conventional? = @conventional

      # This inventory with its files' list items cut to OutlineBudget, the block giving the bytes each inventory tried
      # prints as.
      #: () { (CandidateInventory) -> Integer } -> CandidateInventory
      def within_budget(&printed_bytes)
        with(OutlineBudget.new(@outlines).cut(@listing) { |listing| printed_bytes.call(with(listing)) })
      end

      # Each list that names a file, in OWNER_ASK_KEYS' order, with the paths its ask names inline: all of
      # them when there are at most NAMED_INLINE_AT_MOST, and none beyond.
      #: () -> Hash[String, Array[String]]
      def owner_asks
        OWNER_ASK_KEYS.select { |key| @lists[key]&.any? }.to_h do |key|
          paths = @lists.fetch(key).map { |entry| named(entry) }
          [key, paths.length > NAMED_INLINE_AT_MOST ? [] : paths]
        end
      end

      private

      #: (Hash[String, untyped]) -> CandidateInventory
      def with(listing)
        CandidateInventory.new(listing, untracked: @untracked, outlines: @outlines, conventional: @conventional)
      end

      # The path one list entry names: a file's path, a folder, or the path itself.
      #: (untyped) -> String
      def named(entry) = entry.is_a?(Hash) ? entry.fetch("path") { entry.fetch("folder") } : entry
    end
  end
end

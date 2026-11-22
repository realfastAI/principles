# typed: strict
# frozen_string_literal: true

require "find"
require_relative "../error"
require_relative "ignored_by_git"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The instruction files an agent host loads by convention, as list-candidate-files finds them in the project: each
    # readable one with its length, those that cannot be read, those in a folder that often holds test data, and in
    # git those git ignores.
    class CandidateFilesFound
      # Folders the inventory never enters: version control, this tool's own records, and installed packages.
      PRUNED_FOLDERS = %w[.git .principles .memeplex .coord node_modules vendor .bundle].freeze

      # The instruction files an agent host loads by convention, beside any explicitly selected paths.
      CANDIDATE_NAMES = %w[CLAUDE.md AGENTS.md].freeze
      # Claude Code's rules, skills, agents and settings, and Codex's skills in .agents/skills, hooks in
      # .codex/hooks.json and custom agents in .codex/agents.
      CANDIDATE_PATH = %r{(?:\A|/)(?:\.claude/(?:rules/|skills/|agents/|settings[^/]*\.json\z)|\.agents/skills/|
                          \.codex/(?:hooks\.json\z|agents/))}x

      # Folder names that often hold test data shaped like guidance, such as a sample CLAUDE.md under
      # spec/fixtures/. A name is a hint, not a fact: the agent decides, so these files stay listed and are
      # named here with the folder that matched (alpha 009 friction 1).
      TEST_DATA_FOLDER = %r{(?:\A|/)(fixtures?|examples?|samples?)/}

      # One readable candidate: its path, its length in characters, and for a link the file it leads to.
      # The stand-in project lists by it too, so the two cannot disagree on the shape.
      #: (String, text: String, leads_to: String) -> Hash[String, untyped]
      def self.listed(path, text:, leads_to:)
        entry = { "path" => path, "characters" => text.length }
        leads_to == path ? entry : entry.merge("symlink_to" => leads_to)
      end

      # also names more files to list, inside the project, beside those hosts load by convention; without
      # conventional, only also and the matches of matching are listed.
      #: (ProjectFiles, ?also: Array[String], ?matching: Array[String], ?conventional: bool) -> void
      def initialize(files, also: [], matching: [], conventional: true)
        @files = files
        @also = also
        @matching = matching
        @conventional = conventional
      end

      #: () -> Hash[String, untyped]
      def to_h
        walked = candidate_paths
        candidates = walked | @also
        ignored = IgnoredByGit.new(@files.root, candidates).facts
        listed = listing(candidates - (ignored&.fetch("ignored") || [])).merge(additional_search_paths(walked))
        ignored ? listed.merge(ignored) : listed
      end

      private

      # Explicit matches before ignore/readability filtering; counts of zero remain observable.
      #: (Array[String]) -> Hash[String, untyped]
      def additional_search_paths(paths)
        return { "selected_files" => @also.uniq.sort } if @matching.empty?

        matches = @matching.to_h { |glob| [glob, paths.select { |path| matches?(glob, path) }] }
        { "selected_files" => (@also | matches.values.flatten).sort,
          "additional_search_paths" => matches.map do |glob, found|
            { "glob" => glob, "matched_files" => found.length }
          end }
      end

      #: (String, String) -> bool
      def matches?(glob, path)
        File.fnmatch?(glob, path, File::FNM_PATHNAME | File::FNM_DOTMATCH | File::FNM_EXTGLOB)
      end

      # Readable file entries and per-path refusals, with the test-data hints for readable entries.
      #: (Array[String]) -> Hash[String, untyped]
      def listing(paths)
        entries, skipped = readable(paths)
        entries = entries.sort_by { |entry| entry.fetch("path") }
        { "files" => entries, "unreadable" => skipped,
          "possibly_test_data" => entries.filter_map { |entry| test_data_hint(entry.fetch("path")) } }
      end

      # Each candidate's path relative to the root, in the order the walk finds them.
      #: () -> Array[String]
      def candidate_paths
        paths = [] #: Array[String]
        Find.find(@files.root) do |absolute|
          next unless file_in_walk?(absolute)

          relative = absolute.delete_prefix("#{@files.root}/")
          paths << relative if candidate?(relative)
        end
        paths
      end

      # Whether this walk visits a file, pruning internal folders and other projects before descending.
      #: (String) -> bool
      def file_in_walk?(absolute)
        return File.basename(absolute) != ".git" unless File.directory?(absolute)

        Find.prune if PRUNED_FOLDERS.include?(File.basename(absolute)) || nested_repository?(absolute)
        false
      end

      # A folder below the root holding its own .git, a worktree's file or a clone's folder, is another project,
      # as git treats it. The root may hold one too: this tool runs in a worktree.
      #: (String) -> bool
      def nested_repository?(absolute)
        absolute != @files.root && File.exist?(File.join(absolute, ".git"))
      end

      # Each path with its length in characters, and the refusal for each that cannot be read.
      #: (Array[String]) -> [Array[Hash[String, untyped]], Array[Hash[String, untyped]]]
      def readable(paths)
        entries = [] #: Array[Hash[String, untyped]]
        skipped = [] #: Array[Hash[String, untyped]]
        paths.each do |relative|
          entries << listed(relative)
        rescue Error => e
          skipped << e.payload
        end
        [entries, skipped]
      end

      #: (String) -> Hash[String, untyped]
      def listed(relative)
        CandidateFilesFound.listed(relative, text: @files.read_text(relative), leads_to: @files.leads_to(relative))
      end

      #: (String) -> Hash[String, String]?
      def test_data_hint(relative)
        folder = relative[TEST_DATA_FOLDER, 1]
        { "path" => relative, "folder" => folder } if folder
      end

      #: (String) -> bool
      def candidate?(relative)
        (@conventional && (CANDIDATE_NAMES.include?(File.basename(relative)) || relative.match?(CANDIDATE_PATH))) ||
          @matching.any? { |glob| matches?(glob, relative) }
      end
    end
  end
end

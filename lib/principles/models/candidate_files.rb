# typed: strict
# frozen_string_literal: true

require_relative "candidate_outline"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The instruction files list-candidate-files offers, shortened without judging what is guidance. A
    # skill's templates, references and examples once filled most of a 10KB inventory (alpha 011
    # friction 2). So Markdown files and harness settings are listed one by one, except inside a skill,
    # where only SKILL.md, the file the harness loads, is listed. Every other file is counted under its
    # directory. Explicit selections are always named, including skill references and non-Markdown text files.
    # The agent still sees where every file is, and decides what to read.
    class CandidateFiles
      # A file a harness reads as settings, listed by name like guidance: Claude Code's settings, and Codex's hooks
      # file and custom agents.
      SETTINGS = %r{(?:\A|/)(?:\.claude/settings[^/]*\.json|\.codex/hooks\.json|\.codex/agents/[^/]+\.toml)\z}
      MARKDOWN = /\.md\z/i
      # A file inside a skill's folder, Claude Code's or Codex's, and whether it is the skill's entry point, spelt
      # SKILL.md or in any other case, which a case-insensitive disk opens all the same.
      IN_SKILL = %r{(?:\A|/)\.(?:claude|agents)/skills/[^/]+/}
      SKILL_ENTRY = %r{(?:\A|/)\.(?:claude|agents)/skills/[^/]+/(?<name>SKILL\.md)\z}i
      # The entry file's name as the skill format spells it.
      SKILL_NAME = "SKILL.md"

      #: (Array[Hash[String, untyped]], text_of: ^(String) -> String, ?selected: Array[String]) -> void
      def initialize(files, text_of:, selected: [])
        @files = files #: Array[Hash[String, untyped]]
        @text_of = text_of
        @selected = selected
        freeze
      end

      # The inventory's files, each Markdown one the survey reads with its outline, the other files counted by
      # directory, and those test-data hints that name a listed file, whose files the survey leaves out unread.
      # The files changed names, which a range of commits changed, list first, each marked changed_in_range.
      #: (Array[Hash[String, untyped]], ?changed: Array[String]) -> Hash[String, untyped]
      def listing(test_data_hints, changed: [])
        outlines = outlines(test_data_hints)
        files = listed.map do |file|
          outline = outlines[file.fetch("path")]
          outline ? file.merge(outline.to_h) : file
        end
        { "files" => changed_first(files, changed),
          "other_files_by_directory" => other_files_by_directory, "possibly_test_data" => hints(test_data_hints) }
      end

      # The outline of each listed Markdown file the survey reads, by path: every one but those the test-data hints
      # name, which the budget cuts by.
      #: (Array[Hash[String, untyped]]) -> Hash[String, CandidateOutline]
      def outlines(test_data_hints)
        test_data = hints(test_data_hints).map { |hint| hint.fetch("path") }
        paths = listed.map { |file| file.fetch("path") }.grep(MARKDOWN)
        (paths - test_data).to_h { |path| [path, CandidateOutline.new(@text_of.call(path))] }
      end

      # Each Markdown or settings file, with its size, and a skill's entry file spelt otherwise than SKILL.md with its
      # name as spelt, a fact; whether a host loads it so is the agent's to check.
      #: () -> Array[Hash[String, untyped]]
      def listed
        @files.select { |file| named?(file.fetch("path")) }.map do |file|
          name = SKILL_ENTRY.match(file.fetch("path"))&.[](:name)
          name.nil? || name == SKILL_NAME ? file : file.merge("skill_file_spelt" => name)
        end
      end

      # Each directory holding other files, and how many.
      #: () -> Array[Hash[String, untyped]]
      def other_files_by_directory
        others = @files.map { |file| file.fetch("path") }.reject { |path| named?(path) }
        others.group_by { |path| directory(path) }.sort.map do |directory, paths|
          { "directory" => directory, "files" => paths.length }
        end
      end

      private

      # files with those changed names first, each marked changed_in_range, and the rest after, each in its order.
      #: (Array[Hash[String, untyped]], Array[String]) -> Array[Hash[String, untyped]]
      def changed_first(files, changed)
        in_range, rest = files.partition { |file| changed.include?(file.fetch("path")) }
        in_range.map { |file| file.merge("changed_in_range" => true) } + rest
      end

      # The test-data hints that name a listed file.
      #: (Array[Hash[String, untyped]]) -> Array[Hash[String, untyped]]
      def hints(test_data_hints)
        paths = listed.map { |file| file.fetch("path") }
        test_data_hints.select { |hint| paths.include?(hint.fetch("path")) }
      end

      #: (String) -> String
      def directory(path)
        parent = path.rpartition("/").first
        parent.empty? ? "." : parent
      end

      #: (String) -> bool
      def named?(path)
        return true if @selected.include?(path)
        return path.match?(SKILL_ENTRY) if path.match?(IN_SKILL)

        path.match?(MARKDOWN) || path.match?(SETTINGS)
      end
    end
  end
end

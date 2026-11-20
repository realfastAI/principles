# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "frontmatter_fields"
require_relative "json_path_query"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # When Claude Code loads a skill: its body when the skill is invoked, and its description, which tells the
    # model the skill exists, at session start, on the files its paths field names, or, for a skill in a folder
    # below the project root, when a file there is first touched. A skill only a person invokes puts nothing in
    # the model's context until they do. This follows Claude Code's skills documentation.
    # This tool shows the paths field as written, and reads disable-model-invocation only as a plain true or false.
    class SkillLoads
      # A skill's own file: SKILL.md in a skill's folder in a .claude/skills folder, at the root or below it.
      SKILL_FILE = %r{\A(?<folder>(?:.*/)?)\.claude/skills/[^/]+/SKILL\.md\z} #: Regexp

      PERSON_ONLY = "disable-model-invocation" #: String

      # The characters of a skill's description and when_to_use the listing keeps (code.claude.com/docs/en/skills,
      # read 2026-11-09); a project can set another with skillListingMaxDescChars, which this tool does not read.
      LISTING_LIMIT = 1536 #: Integer

      # text is the skill's whole file, or nil when it cannot be read; query is the member's, when it is a
      # frontmatter field of the skill.
      #: (String, String?, ?query: String?) -> void
      def initialize(path, text, query: nil)
        @path = path
        @text = text
        @query = query
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h
        lines = @text&.lines or return { "when" => "not_determined" }
        frontmatter = FrontmatterFields.new(path: @path, lines: lines)
        person_only = person_only(frontmatter)
        return not_derived("#{PERSON_ONLY} is not a plain true or false") if person_only.nil?

        description = description(frontmatter, person_only)
        return description if description.key?("not_derived")

        description_member? ? description.merge("skill_part" => "description") : body(person_only, description)
      rescue Error => e
        { "when" => "not_determined", "frontmatter_refused" => e.payload.fetch("code") }
      end

      # What the skill listing loads of the skill: its description and when_to_use lines as written, cut at the
      # listing's limit; nil for a skill only a person invokes, which the listing leaves out, or one this tool cannot
      # read.
      #: () -> String?
      def description_text
        lines = @text&.lines or return nil
        frontmatter = FrontmatterFields.new(path: @path, lines: lines)
        return nil unless person_only(frontmatter) == false

        %w[description when_to_use].filter_map { |field| frontmatter.field_lines("$.#{field}")&.join }
                                   .join[0, LISTING_LIMIT]
      rescue Error
        nil
      end

      private

      # When the skill's body loads, who may invoke it, and when its description loads.
      #: (bool, Hash[String, untyped]) -> Hash[String, untyped]
      def body(person_only, description)
        { "when" => "on_invocation", "invoked_by" => person_only ? "person" : "model_or_person",
          "description" => description }
      end

      # Whether the member is the skill's description field, however its query names it. The docs summary says
      # when_to_use joins the description in the listing; until that is read verbatim, it keeps the body's answer.
      #: () -> bool
      def description_member?
        query = @query or return false
        JsonPathQuery.new(query).top_level_name == "description"
      end

      # Whether only a person invokes the skill: false without the field, nil when it is not a plain true or false.
      #: (FrontmatterFields) -> bool?
      def person_only(frontmatter)
        field = frontmatter.field_lines("$[\"#{PERSON_ONLY}\"]") or return false
        value = field.join.strip.delete_prefix("#{PERSON_ONLY}:").strip
        value == "true" if %w[true false].include?(value)
      end

      # When the description loads.
      #: (FrontmatterFields, bool) -> Hash[String, untyped]
      def description(frontmatter, person_only)
        return { "when" => "not_loaded" } if person_only

        paths = frontmatter.field_lines("$.paths")
        return on_paths(paths) if paths
        return { "when" => "on_files", "files" => [folder] } unless folder.empty?

        { "when" => "session_start" }
      end

      # The description's moment for a skill with a paths field, shown as written.
      #: (Array[String]) -> Hash[String, untyped]
      def on_paths(paths)
        return not_derived("a skill below the project root with a paths field") unless folder.empty?

        { "when" => "on_files", "paths_field" => paths.map(&:chomp) }
      end

      # The folder whose .claude/skills holds the skill: empty at the project root, else ending in a slash.
      #: () -> String
      def folder
        SKILL_FILE.match(@path)&.[](:folder).to_s
      end

      #: (String) -> Hash[String, untyped]
      def not_derived(why)
        { "when" => "not_determined", "not_derived" => why }
      end
    end
  end
end

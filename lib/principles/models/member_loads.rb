# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../data/project_files"
require_relative "frontmatter_fields"
require_relative "member_file"
require_relative "text_size"
require_relative "agent_loads"
require_relative "carrier_kind"
require_relative "hook_commands"
require_relative "plugin_reference"
require_relative "skill_loads"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # When a host loads a member's file into the agent's context, derived from the file's path as the host
    # documents its loading, with the size of what loads. Only Claude Code is derived. A derivation says
    # what the documentation promises, not what loaded in any session. An audit record keeps these loads, and
    # audit-record.schema.json names each field so show-audit prints it; member_loads_spec holds a sample of each
    # branch to hold the two together, so add one there for a new branch.
    class MemberLoads
      # The derivation shared by member and aggregate reports, never evidence of receipt in a session.
      BASIS = { "host" => "claude_code", "kind" => "documented_prediction",
                "session_start_assumption" => "project_root" }.freeze #: Hash[String, String]

      # The instruction files Claude Code loads at session start in the folder it starts in, and once a file is
      # read, written or edited in a folder below it, as its memory documentation says. This tool assumes a session
      # started at the project root.
      INSTRUCTIONS = %w[CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md].freeze

      # The folder Claude Code reads rules from, recursively: a rule loads at start, or with a paths field only
      # on matching files. This tool shows that field as written and never reads its globs.
      RULES = ".claude/rules/"

      # The fields that give the size of the whole file that loads.
      FILE_SIZE_FIELDS = %w[file_bytes estimated_tokens].freeze #: [String, String]

      # The fields that give the member's own share of that file, which moving the member out of it would save.
      MEMBER_SIZE_FIELDS = %w[member_bytes member_tokens].freeze #: [String, String]

      # The fields that give the size of a skill's or agent's description, which loads apart from its body.
      DESCRIPTION_SIZE_FIELDS = %w[description_bytes description_tokens].freeze #: [String, String]

      # A rule in a .claude/rules folder below the project root, whose loading this tool does not derive yet.
      NESTED_RULE = {
        "when" => "not_determined", "not_derived" => "a rules folder below the project root"
      }.freeze #: Hash[String, String]

      # A file of an installed plugin, which reaches a session by the plugin's own means, such as its hooks or
      # skills, which this tool does not derive.
      PLUGIN_FILE = {
        "when" => "not_determined", "not_derived" => "a file of an installed plugin"
      }.freeze #: Hash[String, String]

      # The member's loads, from its whole file as files hold it and its own lines in it; a file that cannot be
      # read gives no size, a member that cannot be found there no size of its own, and freshness reports why.
      #: (Data::ProjectFiles, Locator, hooks: HookCommands) -> MemberLoads
      def self.read(files, locator, hooks:)
        text = files.read_text(locator.path)
        member = begin
          MemberFile.for(path: locator.path, text: text).lines_of(locator).join
        rescue Error
          nil
        end
        new(locator, text, hooks: hooks, member_text: member)
      rescue Error
        new(locator, nil, hooks: hooks)
      end

      # A whole file's loads, with no member's share in it, as LoadedFiles lists each file.
      #: (Data::ProjectFiles, String, hooks: HookCommands) -> MemberLoads
      def self.of_file(files, path, hooks:)
        new(Locator.new("path" => path), files.read_text(path), hooks: hooks)
      rescue Error
        new(Locator.new("path" => path), nil, hooks: hooks)
      end

      # locator is where the member is, as Member#locator gives it; text is its whole file, or nil when it
      # cannot be read, so its size is left out; member_text is the member's own lines, or nil when it was not
      # found, so its own size is left out.
      #: (Locator, String?, hooks: HookCommands, ?member_text: String?) -> void
      def initialize(locator, text, hooks:, member_text: nil)
        @path = locator.path #: String
        @query = locator.query #: String?
        @text = text
        @hooks = hooks
        @member_text = member_text
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h
        named = @hooks.naming(@path)
        { "claude_code" => named.empty? ? claude_code : claude_code.merge("named_in_hooks" => named) }
      end

      # The kind of carrier the member's file is, whose practices a request names for judging and editing it; kept out
      # of to_h, so what each assessment was judged on stays as it was.
      #: () -> CarrierKind
      def carrier_kind = CarrierKind.new(@path, named_in_hooks: @hooks.naming(@path).any?)

      # The moments Claude Code loads the member's file at, as to_h names them.
      #: () -> Array[String]
      def moments
        [claude_code.fetch("when")]
      end

      # Whether Claude Code loads the file by itself at all, by the facility its path makes it.
      #: () -> bool
      def carried?
        moments != ["no_known_carrier"]
      end

      # Whether the whole file loads at session start, so it counts towards what a session starts with.
      #: () -> bool
      def at_session_start?
        moments == ["session_start"]
      end

      # When Claude Code loads the file, by its facility, with the size of what loads.
      #: () -> Hash[String, untyped]
      def claude_code
        return PLUGIN_FILE if PluginReference.in(@path)

        found = loads_by_path
        return { "when" => "no_known_carrier" } unless found

        # A skill's description member costs its description at start, not the file, so it has only its own size.
        return found.merge(member_size) if found["skill_part"]

        found.merge(size, member_size)
      end

      # The member's own lines, its share of the file, with tokens estimated as size does; empty when the member
      # was not found.
      #: () -> Hash[String, Integer]
      def member_size = TextSize.new(@member_text).under(MEMBER_SIZE_FIELDS)

      # The whole file loads, so this is the file's size, with tokens estimated as characters / 4, rounded up; empty
      # when the file cannot be read.
      #: () -> Hash[String, Integer]
      def size = TextSize.new(@text).under(FILE_SIZE_FIELDS)

      # The size of the file's skill or agent description when it loads at session start, apart from the body, as the
      # skill listing or the subagent list reads it; empty for any other file or moment.
      #: () -> Hash[String, Integer]
      def description_at_start
        return {} unless claude_code.dig("description", "when") == "session_start"

        TextSize.new(description_text).under(DESCRIPTION_SIZE_FIELDS)
      end

      private

      # The description lines of the skill or agent the file is, as its facility reads them; nil for any other file.
      #: () -> String?
      def description_text
        facility&.description_text
      end

      # The agent or skill the file is, by its path, which owns when its body and description load; nil for any other
      # file.
      #: () -> (AgentLoads | SkillLoads)?
      def facility
        return AgentLoads.new(@path, @text) if AgentLoads::AGENT_FILE.match?(@path)

        SkillLoads.new(@path, @text, query: @query) if SkillLoads::SKILL_FILE.match?(@path)
      end

      # When Claude Code loads the file, by the facility its path makes it, or nil for a path it does not load
      # by itself.
      #: () -> Hash[String, untyped]?
      def loads_by_path
        if @path.end_with?(".md")
          facility_loads = facility&.to_h
          return facility_loads if facility_loads
          return rule if @path.start_with?(RULES)
          return NESTED_RULE if nested_rule?
        end

        instruction_file
      end

      # Whether the file is in a .claude/rules folder below the project root, whose loading this tool does not derive.
      #: () -> bool
      def nested_rule?
        @path.include?("/#{RULES}")
      end

      # A rule's loading moment, from whether its frontmatter has a paths field; not determined when its file
      # cannot be read or its frontmatter is one this tool refuses to read as lines.
      #: () -> Hash[String, untyped]
      def rule
        lines = @text&.lines or return { "when" => "not_determined" }
        paths = FrontmatterFields.new(path: @path, lines: lines).field_lines("$.paths")
        return { "when" => "session_start" } unless paths

        { "when" => "on_files", "paths_field" => paths.map(&:chomp) }
      rescue Error => e
        { "when" => "not_determined", "frontmatter_refused" => e.payload.fetch("code") }
      end

      # An instruction file's loading moment: at start in the root folder, on files in one below it.
      #: () -> Hash[String, untyped]?
      def instruction_file
        folder = INSTRUCTIONS.filter_map { |name| @path.delete_suffix(name) if @path.end_with?(name) }.min_by(&:length)
        return unless folder
        return { "when" => "session_start" } if folder.empty?

        { "when" => "on_files", "files" => [folder] } if folder.end_with?("/")
      end
    end
  end
end

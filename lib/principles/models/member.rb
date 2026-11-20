# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "locator"
require_relative "meta_principle"
require_relative "report_hooks"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # One member of a principle as its map records it: a file, a Markdown section of it, or a passage
    # starting at a quoted first line. Its id names all three, so an agent can read where the member is
    # from the id alone.
    class Member
      # The Unicode names of the format characters and separators most often met in text, by code point.
      # Ruby has no table of names, so a character missing here is given by its code point alone.
      HIDDEN_CHARACTER_NAMES = {
        0x00AD => "SOFT HYPHEN", 0x061C => "ARABIC LETTER MARK", 0x180E => "MONGOLIAN VOWEL SEPARATOR",
        0x200B => "ZERO WIDTH SPACE", 0x200C => "ZERO WIDTH NON-JOINER", 0x200D => "ZERO WIDTH JOINER",
        0x200E => "LEFT-TO-RIGHT MARK", 0x200F => "RIGHT-TO-LEFT MARK", 0x2028 => "LINE SEPARATOR",
        0x2029 => "PARAGRAPH SEPARATOR", 0x202A => "LEFT-TO-RIGHT EMBEDDING", 0x202B => "RIGHT-TO-LEFT EMBEDDING",
        0x202C => "POP DIRECTIONAL FORMATTING", 0x202D => "LEFT-TO-RIGHT OVERRIDE",
        0x202E => "RIGHT-TO-LEFT OVERRIDE", 0x2060 => "WORD JOINER", 0x2066 => "LEFT-TO-RIGHT ISOLATE",
        0x2067 => "RIGHT-TO-LEFT ISOLATE", 0x2068 => "FIRST STRONG ISOLATE", 0x2069 => "POP DIRECTIONAL ISOLATE",
        0xFEFF => "ZERO WIDTH NO-BREAK SPACE"
      }.freeze #: Hash[Integer, String]

      # The map format each member field needs: a member using a field is unreadable, without loss, by a
      # version older than its format. Every field the member-map schema names is listed; a spec checks it.
      # A new member field that changes what an audit asks or records gets the next format, and
      # Data::MapFiles::NEWEST_FORMAT moves with it.
      FIELD_FORMATS = { "path" => 1, "section" => 1, "starting_at" => 1, "ending_at" => 1, "role" => 1,
                        "key" => 1, "check" => 2, "query" => 2 }.freeze #: Hash[String, Integer]

      # The fields that say where a member's text is; a move replaces them whole.
      LOCATORS = %w[path section starting_at ending_at query].freeze #: [String, String, String, String, String]

      # fields is copied and frozen, so no caller changes a member through the hash it was built from or handed;
      # the copy is shallow, so its strings are the caller's. Principle builds its members from strings it has
      # copied and frozen, so a member in a map shares nothing.
      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields.dup.freeze #: Hash[String, untyped]
        freeze
      end

      # The member's fields, as its map's file holds them.
      #: () -> Hash[String, untyped]
      def to_h = @fields

      # path, path#section or path$query, or either of the first two followed by @ and the passage's first-line
      # anchor.
      #: () -> String
      def id
        id = @fields["section"] ? "#{@fields.fetch("path")}##{@fields["section"]}" : @fields.fetch("path")
        id = "#{id}#{@fields["query"]}" if @fields["query"]
        @fields["starting_at"] ? "#{id}@#{@fields["starting_at"]}" : id
      end

      # What the member is known by across moves: its stored key, which move-member keeps from its id before
      # its first move, or else its id. Audit records file each member's hash under it.
      #: () -> String
      def key
        @fields["key"] || id
      end

      # The move-member options that place a member of this kind, with placeholders to fill: a section's heading,
      # a passage's anchors or a query, or else the whole file's path. Run as printed, a placeholder fails, where a
      # bare --path would silently widen a section or passage to its whole file.
      #: () -> String
      def move_placeholders
        placed = { "section" => "--section HEADING", "starting_at" => "--starting-at TEXT",
                   "ending_at" => "--ending-at TEXT", "query" => "--query QUERY" }
                 .filter_map { |field, option| option if @fields[field] }
        placed.empty? ? "--path PATH" : placed.join(" ")
      end

      # The oldest map format that holds this member: 1 unless it uses a later field.
      #: () -> Integer
      def map_format
        @fields.keys.map { |field| FIELD_FORMATS.fetch(field, 1) }.max || 1
      end

      # The file the member is in.
      #: () -> String
      def path
        @fields.fetch("path")
      end

      # Whether it is its whole file, which no locator but its path narrows, so it holds all the text of every
      # line it spans.
      #: () -> bool
      def whole_file?
        (LOCATORS - ["path"]).none? { |locator| @fields.key?(locator) }
      end

      # Whether its change since a commit reads as the history of its own lines: it is part of its file, and paths,
      # its file's path then and now, are one path.
      #: (Array[String]) -> bool
      def traced_by_lines?(paths) = !whole_file? && paths.one?

      # The lines its change since a commit reads by: lines_now, the first_line and last_line it spans now, when
      # traced_by_lines? says so over paths; else nil, and the change reads as its file's diff.
      #: (Array[String], Hash[String, Integer]) -> Hash[String, Integer]?
      def traced_lines(paths, lines_now) = (lines_now if traced_by_lines?(paths))

      # What the member does for its principle, as the map states it.
      #: () -> String?
      def role
        @fields["role"]
      end

      # The command that enforces the member, which an audit asks the agent to run; nil when it has none.
      #: () -> String?
      def check
        @fields["check"]
      end

      # Each invisible formatting or direction-changing character, or line separator, the member's check
      # holds, in order, as its code point, its name when HIDDEN_CHARACTER_NAMES has it, and its position
      # counted in characters from 1; none when it has no check. This tool prints such characters escaped, and
      # naming them helps a reviewer who scans the command quickly.
      #: () -> Array[String]
      def check_hidden_characters
        check.to_s.each_char.with_index(1).filter_map do |character, position|
          next unless character.match?(/[\p{Cf}\p{Zl}\p{Zp}]/)

          code = character.ord
          [format("U+%04X", code), HIDDEN_CHARACTER_NAMES[code], "at character #{position}"].compact.join(" ")
        end
      end

      # Where the member's text is, as MemberFile finds it.
      #: () -> Hash[String, untyped]
      def reference
        { "path" => @fields.fetch("path"), "heading" => @fields["section"],
          "starting_at" => @fields["starting_at"], "ending_at" => @fields["ending_at"],
          "query" => @fields["query"] }.compact
      end

      # Where the member's text is, as the Locator MemberFile reads.
      #: () -> Locator
      def locator = Locator.new(reference)

      # Which part of principles an upgrade can change this member is: "hook", the plugin's file at the path
      # MetaPrinciple names, or a hooks or settings file whose hooks run the session-start command, whole or a part
      # whose own text, which the block gives only then, runs it too; "skill", the plugin's file at the path
      # MetaPrinciple names; or "passage", a section under the heading setup maps; nil for any other member.
      #: (HookCommands) { () -> String } -> String?
      def package_part(hooks, &)
        return "passage" if @fields["section"] == MetaPrinciple::PASSAGE_HEADING

        start = ReportHooks::SESSION_START.command
        return ("hook" if hooks.passage_runs?(path, start, &)) unless whole_file?
        return "hook" if path == MetaPrinciple::HOOK_PATH || hooks.runs?(path, start)

        "skill" if path == MetaPrinciple::SKILL_PATH
      end

      # This member, still known by key once it has moved. The key is stored only while it differs from the
      # member's id, so a member moved back to where it began has the bytes it had.
      #: (String) -> Member
      def keeping_key(key)
        without = Member.new(@fields.except("key"))
        without.id == key ? without : without.keyed_as(key)
      end

      # This member pointed at the place located names: the new place replaces the old one whole, every other
      # field is kept, and the member is still known by its key.
      #: (Hash[String, untyped]) -> Member
      def moved_to(located)
        Member.new(located.merge(@fields.except(*LOCATORS))).keeping_key(key)
      end

      # This member known by key, as a member added where another moved away from keeps its own audit.
      #: (String) -> Member
      def keyed_as(key) = with("key" => key)

      # This member with fields in place of its own.
      #: (Hash[String, untyped]) -> Member
      def with(fields) = Member.new(@fields.merge(fields))

      # This member with no check.
      #: () -> Member
      def without_check = Member.new(@fields.except("check"))

      # Refuses a place an agent gave that quotes where a passage ends but not where it starts.
      #: () -> void
      def check_location
        return unless @fields["ending_at"] && !@fields["starting_at"]

        raise Error.new("ending_without_start", "--ending-at needs --starting-at",
                        "Quote the passage's opening with --starting-at too.")
      end
    end
  end
end

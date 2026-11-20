# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "json_path_query"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The YAML frontmatter at the head of a Markdown file, read as lines and never parsed as YAML, since a
    # YAML parser over untrusted bytes is attack surface. A field is a top-level `key:` line and the indented,
    # list or blank lines after it; its member is those lines exactly. This tool never interprets a value, so it
    # refuses only what would make a field's lines differ from what the harness reads: an anchor, an alias or
    # a tag, or a line it cannot place in a field.
    class FrontmatterFields
      # A top-level field's opening line, and its name.
      FIELD = /\A([A-Za-z0-9_-]+):(?:\s|\z)/ #: Regexp

      # A node that starts with an anchor, an alias or a tag, after a key or a list dash.
      INDIRECT = /\A\s*(?:-\s+|[^\s:#][^:#]*:\s+)[&*!]/ #: Regexp

      # A value that is a flow collection, after a key or a list dash, such as [a, b] or {a: b}.
      FLOW = /\A\s*(?:-\s+|[^\s:#][^:#]*:\s+)([\[{].*)/ #: Regexp

      # A quoted scalar, whose text is never a node of its own.
      QUOTED = /"(?:[^"\\]|\\.)*"|'(?:[^']|'')*'/ #: Regexp

      # A node inside a flow collection that starts with an anchor, an alias or a tag.
      FLOW_INDIRECT = /[\[{,:]\s*[&*!]/ #: Regexp

      #: (path: String, lines: Array[String]) -> void
      def initialize(path:, lines:)
        @path = path
        @lines = lines
        freeze
      end

      # The line range of the field query names: from its key line through its last non-blank line.
      #: (String) -> [Integer, Integer]
      def field(query)
        name = JsonPathQuery.new(query).top_level_name or refuse_query(query)
        found = fields.select { |field_name, _| field_name == name }
        if found.empty?
          raise Error.new("field_not_found", "#{@path} has no frontmatter field #{name.inspect}",
                          "Name a top-level field its frontmatter has, such as $.description.", @path)
        end
        refuse_duplicate(name) if found.length > 1

        found.fetch(0).last
      end

      # The lines of the field query names, as written, or nil when the frontmatter has no such field; every
      # other refusal still refuses.
      #: (String) -> Array[String]?
      def field_lines(query)
        first, last = field(query)
        (first...last).map { |index| @lines.fetch(index) }
      rescue Error => e
        raise unless e.payload.fetch("code") == "field_not_found"
      end

      # The index of the --- that closes the frontmatter, or nil when the text opens with none; the
      # file's body starts after it.
      #: () -> Integer?
      def closing_line
        return nil unless @lines.first&.chomp == "---"

        (1...@lines.length).find { |i| @lines.fetch(i).chomp == "---" }
      end

      private

      # Each top-level field's name and line range, in order; refused on a line this tool would misread.
      #: () -> Array[[String, [Integer, Integer]]]
      def fields
        closing = closing_line or return []
        starts = (1...closing).select { |i| opens_field?(i) }
        starts.each_with_index.map do |start, n|
          [@lines.fetch(start)[FIELD, 1].to_s, [start, last_filled(start, (starts[n + 1] || closing) - 1) + 1]]
        end
      end

      # The last line from start to last that is not blank, so trailing blank lines stay out of a field.
      #: (Integer, Integer) -> Integer
      def last_filled(start, last)
        last -= 1 while last > start && @lines.fetch(last).strip.empty?
        last
      end

      # Whether line i opens a field, after refusing what this tool cannot read as lines.
      #: (Integer) -> bool
      def opens_field?(index)
        line = @lines.fetch(index)
        refuse_line(index, "an anchor, alias or tag") if line.match?(INDIRECT) || indirect_in_flow?(line)
        return true if line.match?(FIELD)
        return false if line.strip.empty? || line.start_with?(" ", "\t", "-", "#")

        refuse_line(index, "a line that is not a top-level field")
      end

      # Whether line's value is a flow collection holding an anchor, alias or tag outside its quoted text.
      #: (String) -> bool
      def indirect_in_flow?(line)
        flow = line[FLOW, 1] or return false
        flow.gsub(QUOTED, "\"\"").match?(FLOW_INDIRECT)
      end

      #: (Integer, String) -> bot
      def refuse_line(index, what)
        raise Error.new("unsupported_frontmatter", "#{@path} line #{index + 1} holds #{what}",
                        "Frontmatter is read as plain fields. Write the value out in full, or map the " \
                        "file with --starting-at TEXT instead.", @path).including("line" => index + 1)
      end

      #: (String) -> bot
      def refuse_query(query)
        raise Error.new("unsupported_query", "#{query.inspect} is not a supported frontmatter query",
                        "Name one top-level field, such as $.description, or $['allowed-tools'] for a name " \
                        "with a hyphen.", @path)
      end

      #: (String) -> bot
      def refuse_duplicate(name)
        raise Error.new("duplicate_frontmatter_key", "#{@path} names #{name.inspect} more than once",
                        "Keep one #{name} field; the harness may read either.", @path)
      end
    end
  end
end

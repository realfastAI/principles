# typed: strict
# frozen_string_literal: true

require "json"

module Principles
  module Views
    # How a JSON result prints on stdout, and so how many bytes it takes there. Whatever sizes a result for the agent
    # measures it here, so a size it reports is the size it prints. A result prints a field a line, so grep, sed -n
    # and a diff read it as precisely as when it was indented, but unindented and with no space after the colon,
    # since indentation was most of what printing it compact would save, and one grep pattern then fits every output.
    module PrintedJson
      INDENT = ""
      SPACE = ""

      # value as printed, one field a line.
      #: (untyped) -> String
      def self.text(value) = JSON.pretty_generate(value, indent: INDENT, space: SPACE)

      # The bytes value prints as.
      #: (untyped) -> Integer
      def self.bytes(value) = text(value).bytesize

      # value as printed, but for the array at path, each of whose entries prints compact on a line of its own. Each
      # object on the way to it prints a field a line, and every other field as text prints it, depth objects in.
      #: (untyped, Array[String], ?Integer) -> String
      def self.with_entries_on_lines(value, path, depth = 0)
        return entry_lines(value, depth) if path.empty?

        fields = value.map do |name, field|
          shown = name == path.first ? with_entries_on_lines(field, path.drop(1), depth + 1) : nested(field, depth + 1)
          "#{INDENT * (depth + 1)}#{JSON.generate(name)}:#{SPACE}#{shown}"
        end
        "{\n#{fields.join(",\n")}\n#{INDENT * depth}}"
      end

      # field as text prints it, depth objects in.
      #: (untyped, Integer) -> String
      def self.nested(field, depth) = JSON.pretty_generate(field, indent: INDENT, space: SPACE, depth:)

      # entries a compact line each, one step in from depth.
      #: (Array[untyped], Integer) -> String
      def self.entry_lines(entries, depth)
        return "[]" if entries.empty?

        "[\n#{entries.map { "#{INDENT * (depth + 1)}#{JSON.generate(it)}" }.join(",\n")}\n#{INDENT * depth}]"
      end
      private_class_method :nested, :entry_lines
    end
  end
end

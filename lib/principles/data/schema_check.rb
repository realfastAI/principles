# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"
require_relative "../prose_list"
require_relative "expected_type"
require_relative "known_fields"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Checks parsed JSON against one of the schemas in schemas/, with the standard library alone, so a run
    # needs no gem. It supports only KEYWORDS, which is what this tool's own schemas use; a spec fails on
    # a schema that uses another, and a conformance spec compares its verdicts with json_schemer's.
    class SchemaCheck
      # The keywords a schema may use, besides annotations such as title and description.
      KEYWORDS = %w[type properties required additionalProperties items minLength pattern enum const].freeze
      # This tool's own schema keyword, on an object that refuses fields it does not name: for a field an agent
      # may put there by mistake, where it belongs instead, which its refusal adds, as {field => text}.
      UNREAD_FIELD_ADVICE = "x-unread-field-advice"
      # This tool's own schema keyword, on a string with a pattern: what to say when the value does not match, in place
      # of the pattern, for a field whose pattern holds a template's placeholder, which another template's wording
      # fails.
      UNMATCHED_ADVICE = "x-unmatched-advice"
      # Keywords that only describe, and check nothing; the refusal advice is worded into a refusal.
      ANNOTATIONS = %W[$schema $id title description #{ExpectedType::ADVICE} #{UNREAD_FIELD_ADVICE}
                       #{UNMATCHED_ADVICE}].freeze

      # schema is the one named, unless a narrower one is given.
      #: (String, ?Hash[String, untyped]) -> void
      def initialize(name, schema = JSON.parse(File.read(File.join(__dir__, "schemas", "#{name}.schema.json"))))
        @name = name
        @schema = schema #: Hash[String, untyped]
      end

      # The check of only the top-level fields named, any other field let through, so the part a later step depends
      # on is checked before the rest, as an answer's head is.
      #: (Array[String]) -> SchemaCheck
      def only(fields)
        SchemaCheck.new(@name, @schema.merge("properties" => @schema.fetch("properties", {}).slice(*fields),
                                             "required" => @schema.fetch("required", []) & fields,
                                             "additionalProperties" => true))
      end

      # Each place data breaks the schema, as a JSON pointer and what is wrong there, sorted by pointer.
      #: (untyped) -> Array[Hash[String, String]]
      def problems(data)
        found = [] #: Array[Hash[String, String]]
        check(@schema, data, "", found)
        found.sort_by { |problem| problem.fetch("pointer") }
      end

      # data with only the fields the schema names, for printing; KnownFields owns the rule.
      #: (untyped) -> untyped
      def known(data)
        KnownFields.new(@schema).of(data)
      end

      # data when it fits the schema; otherwise a refusal with code, giving source and each failing field, whose
      # message calls data named.
      #: (untyped, code: String, source: String, repair: String, ?named: String) -> untyped
      def checked(data, code:, source:, repair:, named: source)
        found = problems(data)
        return data if found.empty?

        raise Error.new(code, "#{named} is not in the shape this tool reads", repair, source, fields: found)
      end

      private

      #: (Hash[String, untyped], untyped, String, Array[Hash[String, String]]) -> void
      def check(schema, value, pointer, found)
        expected = ExpectedType.new(schema)
        return found << problem(pointer, "must be #{expected}") unless expected.matches?(value)

        check_value(schema, value, pointer, found)
        check_object(schema, value, pointer, found) if value.is_a?(Hash)
        check_items(schema, value, pointer, found) if value.is_a?(Array)
      end

      #: (Hash[String, untyped], untyped, String, Array[Hash[String, String]]) -> void
      def check_value(schema, value, pointer, found)
        found << problem(pointer, "must be #{JSON.generate(schema["const"])}") if mismatched_const?(schema, value)
        found << problem(pointer, "must be one of #{choices(schema)}") if schema["enum"]&.include?(value) == false
        check_string(schema, value, pointer, found) if value.is_a?(String)
      end

      #: (Hash[String, untyped], String, String, Array[Hash[String, String]]) -> void
      def check_string(schema, value, pointer, found)
        found << problem(pointer, "must not be empty") if too_short?(schema, value)
        return unless unmatched?(schema, value)

        found << problem(pointer, schema[UNMATCHED_ADVICE] || "must match #{schema["pattern"]}")
      end

      #: (Hash[String, untyped], String) -> bool
      def unmatched?(schema, value)
        pattern = schema["pattern"]
        pattern ? !Regexp.new(pattern).match?(value) : false
      end

      #: (Hash[String, untyped], untyped) -> bool
      def mismatched_const?(schema, value)
        schema.key?("const") && value != schema["const"]
      end

      #: (Hash[String, untyped]) -> String
      def choices(schema)
        schema.fetch("enum").map { |each| JSON.generate(each) }.join(", ")
      end

      #: (Hash[String, untyped], untyped) -> bool
      def too_short?(schema, value)
        minimum = schema["minLength"]
        return false unless minimum && value.is_a?(String)

        value.length < minimum
      end

      #: (Hash[String, untyped], Hash[String, untyped], String, Array[Hash[String, String]]) -> void
      def check_object(schema, value, pointer, found)
        schema.fetch("required", []).each do |key|
          found << problem(child(pointer, key), "is required") unless value.key?(key)
        end
        value.each { |key, each| check_property(schema, key, each, pointer, found) }
      end

      #: (Hash[String, untyped], String, untyped, String, Array[Hash[String, String]]) -> void
      def check_property(schema, key, value, pointer, found)
        # A field the schema names, else additionalProperties: false refuses it, or a schema checks it.
        property = schema.fetch("properties", {})[key] || schema["additionalProperties"]
        if property.is_a?(Hash)
          check(property, value, child(pointer, key), found)
        elsif property == false
          found << problem(child(pointer, key), unread(schema, key))
        end
      end

      # Why key is refused in an object schema checks: not a field read there, the fields that are, so the agent need
      # not guess them, and what the schema says of key, if anything.
      #: (Hash[String, untyped], String) -> String
      def unread(schema, key)
        read = schema.fetch("properties", {}).keys
        ["is not a field this tool reads here", *("it reads #{ProseList.new(read)}" unless read.empty?),
         *schema.fetch(UNREAD_FIELD_ADVICE, {})[key]].join("; ")
      end

      #: (Hash[String, untyped], Array[untyped], String, Array[Hash[String, String]]) -> void
      def check_items(schema, value, pointer, found)
        items = schema["items"] or return
        value.each_with_index { |each, index| check(items, each, child(pointer, index.to_s), found) }
      end

      # The pointer to key inside pointer, escaped as RFC 6901 asks.
      #: (String, String) -> String
      def child(pointer, key)
        "#{pointer}/#{key.gsub("~", "~0").gsub("/", "~1")}"
      end

      #: (String, String) -> Hash[String, String]
      def problem(pointer, text)
        { "pointer" => pointer, "problem" => text }
      end
    end
  end
end

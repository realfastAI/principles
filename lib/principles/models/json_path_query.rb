# typed: strict
# frozen_string_literal: true

require "strscan"
require_relative "../error"
require_relative "json_path_string"
require_relative "json_path_selectors"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # A query in this tool's own profile of RFC 9535 JSONPath: from $, name selectors in dot or bracket
    # form, wildcards, and filters that keep the children whose relative paths equal strings, joined by &&.
    # A query outside the profile is refused whole, never half-read, so an id always holds standard JSONPath
    # and a later full implementation changes no map. It only evaluates over values already parsed as JSON.
    class JsonPathQuery
      # A member-name shorthand, as RFC 9535 defines it for ASCII.
      SHORTHAND = /[A-Za-z_][A-Za-z0-9_]*/ #: Regexp

      # The repair this tool gives when it has no exact rewrite to offer.
      GRAMMAR = "Use $ followed by .name, ['name'], .* or [*], and [?@.field=='text' && ...] filters." #: String

      #: (String) -> void
      def initialize(query)
        @query = query
        @segments = parsed(StringScanner.new(query)) #: Array[(JsonPathName | JsonPathWildcard | JsonPathFilter)]
        freeze
      end

      # The nodes this query selects from value, in document order.
      #: (untyped) -> Array[untyped]
      def select(value)
        @segments.reduce([value]) { |nodes, selector| nodes.flat_map { |node| selector.select(node) } }
      end

      # The name of the one top-level member this query selects, or nil when it selects anything else.
      #: () -> String?
      def top_level_name
        only = @segments.first
        only.name if @segments.length == 1 && only.is_a?(JsonPathName)
      end

      private

      #: (StringScanner) -> Array[(JsonPathName | JsonPathWildcard | JsonPathFilter)]
      def parsed(scanner)
        refuse("it does not start with $") unless scanner.scan("$")
        segments = [] #: Array[(JsonPathName | JsonPathWildcard | JsonPathFilter)]
        segments << segment(scanner) until scanner.eos?
        segments
      end

      #: (StringScanner) -> (JsonPathName | JsonPathWildcard | JsonPathFilter)
      def segment(scanner)
        refuse("descendant segments (..) are outside the profile") if scanner.check("..")
        return dotted(scanner) if scanner.scan(".")
        return bracketed(scanner) if scanner.scan("[")

        refuse("it has #{scanner.rest.inspect} where a segment should start")
      end

      #: (StringScanner) -> (JsonPathName | JsonPathWildcard | JsonPathFilter)
      def dotted(scanner)
        return JsonPathWildcard.new if scanner.scan("*")

        start = scanner.pos - 1
        name = scanner.scan(SHORTHAND) or refuse("a . must be followed by a name or *")
        refuse_hyphenated(scanner, start, name) if scanner.check(/-/)
        JsonPathName.new(name)
      end

      # A name with a hyphen cannot follow a dot in RFC 9535, so the repair gives the query with it bracketed.
      #: (StringScanner, Integer, String) -> bot
      def refuse_hyphenated(scanner, start, name)
        name += scanner.scan(/[A-Za-z0-9_-]+/).to_s
        rewritten = "#{@query[0...start]}['#{name}']#{scanner.rest}"
        refuse("a name with a hyphen cannot follow a dot", "Put the name in brackets: write it #{rewritten}.")
      end

      #: (StringScanner) -> (JsonPathName | JsonPathWildcard | JsonPathFilter)
      def bracketed(scanner)
        selector = if scanner.scan("*") then JsonPathWildcard.new
                   elsif scanner.scan("?") then JsonPathFilter.new(conditions(scanner))
                   elsif scanner.check(/['"]/) then JsonPathName.new(JsonPathString.new(@query).read(scanner))
                   else refuse("this selector is outside the profile, which takes names, * and ?filters")
                   end
        refuse("this selector is outside the profile, or not closed") unless scanner.scan("]")
        selector
      end

      # The filter's conditions: @-relative paths each equal to a string, joined by &&.
      #: (StringScanner) -> Array[[Array[String], String]]
      def conditions(scanner)
        found = [condition(scanner)]
        found << condition(scanner) while scanner.scan(/\s*&&\s*/)
        scanner.skip(/\s*/)
        found
      end

      #: (StringScanner) -> [Array[String], String]
      def condition(scanner)
        scanner.skip(/\s*/)
        refuse("a filter must compare an @ path") unless scanner.scan("@")
        path = [] #: Array[String]
        path << relative_name(scanner) while scanner.check(/\.|\[/)
        refuse("a filter compares with == only") unless scanner.scan(/\s*==\s*/)
        refuse("a filter compares with a quoted string only") unless scanner.check(/['"]/)
        [path, JsonPathString.new(@query).read(scanner)]
      end

      #: (StringScanner) -> String
      def relative_name(scanner)
        if scanner.scan(".")
          scanner.scan(SHORTHAND) or refuse("a . in a filter path must be followed by a name")
        else
          scanner.scan("[")
          refuse("a [ in a filter path must hold a quoted name") unless scanner.check(/['"]/)
          name = JsonPathString.new(@query).read(scanner)
          refuse("a [ in a filter path is not closed") unless scanner.scan("]")
          name
        end
      end

      #: (String, ?String) -> bot
      def refuse(why, repair = GRAMMAR)
        raise Error.new("unsupported_query", "#{@query.inspect} is outside the supported JSONPath profile: #{why}",
                        repair)
      end
    end
  end
end

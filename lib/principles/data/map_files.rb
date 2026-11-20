# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"
require_relative "schema_check"
require_relative "principles_subfolder"
require_relative "json_text"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The member maps this tool writes from the agent's answers: one JSON file per principle under
    # .principles/maps/, committed in the audited repository. A map holds a description and its members,
    # each a project file, optionally narrowed to one Markdown section, with the role it plays.
    class MapFiles
      # The newest map format ordinary current-map reads accept. Models::Principle says which member fields need which
      # format, and a spec ties the two together.
      NEWEST_FORMAT = 2

      #: (PrinciplesSubfolder) -> void
      def initialize(directory)
        @directory = directory
      end

      #: () -> Array[String]
      def ids
        @directory.ids
      end

      # Which of the folder and its earlier name hold this subfolder.
      #: () -> Array[String]
      def held_in
        @directory.held_in
      end

      #: (String) -> bool
      def exist?(id)
        @directory.exist?(id)
      end

      # The map id, which exists: Models::MappedPrinciples refuses one that does not, since which command creates it is
      # a decision.
      #: (String) -> Hash[String, untyped]
      def read(id)
        parse(id, @directory.read(id, shown_as: relative(id)))
      end

      # The map id from text read elsewhere, such as the map's file at commit, checked against its schema.
      #: (String, String, ?commit: String?) -> Hash[String, untyped]
      def parse(id, text, commit: nil)
        map = parsed_fields(id, text)
        refuse_newer(id, map, commit)
        checked_map(id, map, commit)
      end

      # Historical link interpretation is separate from the public current-map format ceiling.
      #: (String, String, commit: String?) -> Hash[String, untyped]
      def parse_history(id, text, commit:)
        map = parsed_fields(id, text)
        refuse_newer(id, map, commit) unless linked_format?(map)
        checked_map(id, map, commit)
      end

      #: (String, Hash[String, untyped]) -> void
      def write(id, map)
        @directory.write(id, "#{JSON.pretty_generate(map)}\n")
      end

      #: (String) -> void
      def remove(id) = @directory.remove(id, shown_as: relative(id))

      #: (String) -> String
      def relative(id)
        File.join(PrinciplesSubfolder::FOLDER, "maps", "#{id}.json")
      end

      # Where map id was kept before the folder took its name now, so history reads it at earlier commits.
      #: (String) -> String
      def earlier_relative(id)
        File.join(PrinciplesSubfolder::EARLIER_FOLDER, "maps", "#{id}.json")
      end

      private

      #: (String, String) -> untyped
      def parsed_fields(id, text)
        JsonText.new(text).parsed
      rescue JSON::ParserError => e
        raise Error.new("unparseable_map", e.message, "Repair this map file or restore it from version control.",
                        relative(id))
      end

      #: (untyped) -> bool
      def linked_format?(map) = map.is_a?(Hash) && map["format"].eql?(3)

      #: (String, untyped, String?) -> Hash[String, untyped]
      def checked_map(id, map, commit)
        problems = SchemaCheck.new("member-map").problems(map)
        problems += SchemaCheck.new("member-map-history").problems(map) if linked_format?(map)
        return map if problems.empty?

        raise Error.new("invalid_map", "#{where(id, commit)} is not in the shape this tool writes",
                        "Repair each field listed, or restore the map from version control.", relative(id),
                        fields: problems)
      end

      # Refuses a map a newer version wrote, before its schema is checked: its fields may be ones this
      # version cannot read without losing what they say, and the agent must not be told to repair or
      # restore a map that is not broken.
      #: (String, untyped, String?) -> void
      def refuse_newer(id, map, commit)
        format = map.is_a?(Hash) ? map["format"] : nil
        return unless format.is_a?(Integer) && format > NEWEST_FORMAT

        raise Error.new("newer_format", "#{where(id, commit)} is format #{format}, written by a newer version " \
                                        "than this one; this one reads up to format #{NEWEST_FORMAT}",
                        "Update the installed principles plugin or gem, then run the command again. " \
                        "Leave the map as it is: it is not broken.",
                        relative(id))
      end

      #: (String, String?) -> String
      def where(id, commit)
        commit ? "#{relative(id)} at commit #{commit[0, 12]}" : relative(id)
      end
    end
  end
end

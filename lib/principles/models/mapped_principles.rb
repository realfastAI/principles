# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../data/map_files"
require_relative "principle"
require_relative "meta_principle"
require_relative "unknown_principle"
require_relative "project_history"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Every principle the project maps, each loaded and saved as its map through Data::MapFiles.
    class MappedPrinciples
      # A principle id names its principle in lower-kebab-case.
      ID_FORMAT = Data::PrincipleId::FORMAT #: Regexp

      #: (Data::MapFiles, ProjectHistory) -> void
      def initialize(files, history)
        @files = files
        @history = history
      end

      #: () -> Array[String]
      def ids
        @files.ids
      end

      # The mapped rules a survey compares with its candidate principles, without audit or freshness reads.
      #: () -> Array[Hash[String, untyped]]
      def descriptions
        ids.map do |id|
          find(id).description_with_id
        rescue Error => e
          { "id" => id, "refusal" => e.payload }
        end
      end

      # The id of map id, or of every map when id is nil; an id no map has is refused, as find refuses it.
      #: (String?) -> Array[String]
      def ids_of(id)
        return ids unless id

        find(id)
        [id]
      end

      # Every path a map this tool can read names, once each; a map it cannot read names none, so one broken map
      # still leaves the others' files known.
      #: () -> Array[String]
      def readable_paths
        ids.flat_map do |id|
          find(id).members.paths
        rescue Error
          []
        end.uniq
      end

      # Whether a map named id exists, whatever it holds.
      #: (String) -> bool
      def mapped?(id) = @files.exist?(id)

      # Whether principles is set up: the meta-principle's map names a keeping place, a member of any kind. That says
      # a place is named, not that the principle is held, which its audit finds. A map this version cannot read, in a
      # newer format, unparseable or invalid, counts, since it may well have members, so no read refuses over it.
      #: () -> bool
      def set_up?
        return false unless mapped?(MetaPrinciple::ID)

        begin
          !find(MetaPrinciple::ID).unstarted?
        rescue Error
          true
        end
      end

      # The map named id, refused when there is none; Data::MapFiles refuses one that is unparseable.
      #: (String) -> Principle
      def find(id)
        refuse_unknown(id)
        Principle.from_map(id, @files.read(id), files: @files)
      end

      # The map id as text read elsewhere holds it, such as its file at commit, the one an audit began from.
      #: (String, String, ?commit: String?) -> Principle
      def parsed(id, text, commit: nil)
        Principle.from_map(id, @files.parse(id, text, commit: commit), files: @files, commit: commit)
      end

      #: (String, String, commit: String?) -> Principle
      def parsed_history(id, text, commit:)
        Principle.from_map(id, @files.parse_history(id, text, commit: commit), files: @files, commit: commit)
      end

      # A new map for id with no members, not yet saved. It is refused unless id is lower-kebab-case and not
      # yet mapped, and is not the meta-principle's, which setup starts; only then is the description asked for.
      #: (String) { () -> String } -> Principle
      def create(id, &)
        refuse_unavailable(id)
        MetaPrinciple.refuse_explicit_creation(id)
        refuse_uncommitted_removal(id)
        Principle.new(id, { "description" => yield, "members" => [] })
      end

      # The map a new member of principle id joins: the map named id, or, while the meta-principle has none, the map
      # it starts with, not yet saved, so that map is written only with its first member (T74). Any other id no map
      # has is refused, as find refuses it.
      #: (String) -> Principle
      def addable(id)
        return find(id) if mapped?(id) || !MetaPrinciple.id?(id)

        refuse_uncommitted_removal(id)
        Principle.new(id, MetaPrinciple.starting_fields)
      end

      # The map named id, refused when it has no members to audit.
      #: (String) -> Principle
      def auditable(id)
        map = find(id)
        return map unless map.members.empty?

        raise Error.new("map_has_no_members", "#{id} has no members to audit",
                        "Add its members: #{Error::EXECUTABLE} add-member #{id} PATH --role ROLE", file(id))
      end

      # Writes map's file and names it, relative to the project.
      #: (Principle) -> String
      def save(map)
        @files.write(map.id, map.to_h)
        file(map.id)
      end

      # Removes only the map, after the command's audit-entry guard; no member or audit file is changed.
      #: (Principle) -> String
      def remove(map)
        @files.remove(map.id)
        file(map.id)
      end

      # The file map id is kept in, relative to the project.
      #: (String) -> String
      def file(id)
        @files.relative(id)
      end

      # The file map id was kept in under the folder's earlier name, relative to the project.
      #: (String) -> String
      def earlier_file(id)
        @files.earlier_relative(id)
      end

      private

      #: (String) -> void
      def refuse_uncommitted_removal(id)
        return unless [file(id), earlier_file(id)].any? { |path| @history.entry_at_head?(path) }

        raise Error.new("map_removal_not_committed", "#{id}'s map is still present at committed HEAD",
                        "Commit its removal or ID change before recreating #{id}, then retry this command.", file(id))
      end

      # A principle no map names, with the commands that create one and list the rest. For the meta-principle's id the
      # repair leads to setup, not create-principle, which would give its map another description and no activation;
      # setup writes no map, and the add-member it prints creates it (T74).
      #: (String) -> void
      def refuse_unknown(id)
        return if mapped?(id)

        raise UnknownPrinciple.new(id).refusal
      end

      #: (String) -> void
      def refuse_unavailable(id)
        unless id.match?(ID_FORMAT)
          raise Error.new("invalid_id", "#{id} is not lower-kebab-case",
                          "Name the principle in lower-kebab-case, such as express-intent.")
        end
        return unless @files.exist?(id)

        raise Error.new("principle_exists", "#{id} is already mapped",
                        "To change its description: #{Error::EXECUTABLE} change-description #{id} --description TEXT",
                        file(id))
      end
    end
  end
end

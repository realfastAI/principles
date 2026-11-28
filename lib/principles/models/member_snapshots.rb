# typed: strict
# frozen_string_literal: true

require_relative "audited_member_lines"
require_relative "located_text"
require_relative "missing_files"
require_relative "unresolved_plugin_members"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Each of a map's members by id, where it is in its file now and the hash of what it says there, as
    # the project located them all.
    class MemberSnapshots
      # Locate every member before refusing, so one broken reference never hides another. A plugin member no
      # installed plugin gives is refused apart from the broken ones, since no move or removal in the project fixes it.
      #: (Project, Principle) -> MemberSnapshots
      def self.read(project, map)
        found, broken, unresolved = located(project, map.members)
        raise MissingFiles.new(broken, principle: map.id, history: project.history).refusal_of_map unless broken.empty?

        unresolved = UnresolvedPluginMembers.new(unresolved, principle: map.id)
        raise unresolved.refusal unless unresolved.empty?

        new(found)
      end

      # Each of members located by id, and the entry of each that cannot be, with its refusal: the project's
      # members apart from the plugin members no installed plugin gives.
      #: (Project, PrincipleMembers)
      #|  -> [Hash[String, LocatedText], Array[Hash[String, untyped]], Array[Hash[String, untyped]]]
      def self.located(project, members)
        broken = [] #: Array[Hash[String, untyped]]
        unresolved = [] #: Array[Hash[String, untyped]]
        found = {} #: Hash[String, LocatedText]
        members.each do |member|
          found[member.id] = project.located_text(member.locator)
        rescue Error => e
          (member.plugin_reference ? unresolved : broken) << { "id" => member.id }.merge(e.payload.except("status"))
        end
        [found, broken, unresolved]
      end
      private_class_method :located

      #: (Hash[String, LocatedText]) -> void
      def initialize(by_id)
        @by_id = by_id.freeze #: Hash[String, LocatedText]
        freeze
      end

      # Each member's located text by id.
      #: () -> Hash[String, LocatedText]
      def to_h = @by_id

      # Where the member id is in its file now, and the hash of what it says there.
      #: (String) -> LocatedText
      def of(id) = @by_id.fetch(id)

      # Each member's id and the hash of its text now.
      #: () -> Hash[String, String]
      def hashes = @by_id.transform_values(&:sha256)

      # The lines the members span now, against which another principle's evidence is said to share them.
      #: () -> AuditedMemberLines
      def audited_lines = AuditedMemberLines.new(@by_id)
    end
  end
end

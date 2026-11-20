# typed: strict
# frozen_string_literal: true

require_relative "audited_member_lines"
require_relative "located_text"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Each of a map's members by id, where it is in its file now and the hash of what it says there, as
    # the project located them all.
    class MemberSnapshots
      # Locate every member before refusing, so one broken reference never hides another.
      #: (Project, Principle) -> MemberSnapshots
      def self.read(project, map)
        broken = [] #: Array[Hash[String, untyped]]
        found = map.members.to_h do |member|
          [member.id, project.locate(member.locator)]
        rescue Error => e
          broken << { "id" => member.id }.merge(e.payload.except("status"))
          [member.id, {}]
        end
        broken.empty? ? new(found) : project.refuse_broken(map.id, broken)
      end

      #: (Hash[String, Hash[String, untyped]]) -> void
      def initialize(by_id)
        @by_id = by_id.freeze #: Hash[String, Hash[String, untyped]]
        freeze
      end

      # Each member's snapshot by id.
      #: () -> Hash[String, Hash[String, untyped]]
      def to_h = @by_id

      # Where the member id is in its file now, and the hash of what it says there.
      #: (String) -> LocatedText
      def of(id) = LocatedText.of(@by_id.fetch(id))

      # Each member's id and the hash of its text now.
      #: () -> Hash[String, String]
      def hashes = @by_id.transform_values { |snapshot| snapshot.fetch("sha256") }

      # The lines the members span now, against which another principle's evidence is said to share them.
      #: () -> AuditedMemberLines
      def audited_lines = AuditedMemberLines.new(@by_id.transform_values { LocatedText.of(it) })
    end
  end
end

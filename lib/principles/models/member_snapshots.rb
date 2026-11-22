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
        found = {} #: Hash[String, LocatedText]
        map.members.each do |member|
          found[member.id] = project.located_text(member.locator)
        rescue Error => e
          broken << { "id" => member.id }.merge(e.payload.except("status"))
        end
        broken.empty? ? new(found) : project.refuse_broken(map.id, broken)
      end

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

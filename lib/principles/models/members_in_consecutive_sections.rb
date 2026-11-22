# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member"
require_relative "located_text"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Members in complete sections meeting the new section at a literal line boundary, in other unaudited maps.
    class MembersInConsecutiveSections
      #: (Project, Member) -> void
      def initialize(project, member)
        @project = project
        @member = member
        @located = project.located_text(member.locator) #: LocatedText
        @records = project.audit_records #: AuditRecords
        freeze
      end

      # Literal section boundaries are not evidence that the rules belong to one principle.
      #: (except: String) -> Array[Hash[String, untyped]]
      def elsewhere(except:)
        return [] unless @member.locator.complete_section? && @records.known_no_completed_audit?(except)

        maps = @project.principles
        (maps.ids - [except]).flat_map { |id| in_map(maps, id) }
      end

      private

      # Optional feedback leaves unreadable maps to list-member-problems rather than blocking the write.
      #: (MappedPrinciples, String) -> Array[Hash[String, untyped]]
      def in_map(maps, id)
        return [] unless @records.known_no_completed_audit?(id)

        maps.find(id).members.to_a.filter_map { |member| consecutive(member, id) }
      rescue Error
        []
      end

      #: (Member, String) -> Hash[String, untyped]?
      def consecutive(member, id)
        return unless member.locator.complete_section? && @project.same_file?(member.path, @located.path)

        found = @project.located_text(member.locator)
        return unless @located.span.consecutive_with?(found.span)

        { "principle_id" => id, "member_id" => member.id, "path" => member.path,
          "role" => member.role }.merge(found.lines)
      rescue Error
        nil
      end
    end
  end
end

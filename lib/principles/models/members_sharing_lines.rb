# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "line_span"
require_relative "located_text"
require_relative "member"
require_relative "member_elsewhere"
require_relative "members_elsewhere"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The members whose text shares a line with one member located in its file, so one edit there shows on
    # each. The project locates the others; a member this tool cannot find now is left out, since show-principle
    # reports it.
    class MembersSharingLines
      # The members sharing a line with member, located where it is now; refuses as Project#locate does when it
      # cannot be found.
      #: (Project, Member) -> MembersSharingLines
      def self.of(project, member)
        new(project, project.located_text(member.locator), id: member.id, whole_file: member.whole_file?)
      end

      # located is the text found for one member, its path and lines, id is that member's id, and whole_file whether
      # it is its whole file.
      #: (Project, LocatedText, id: String, ?whole_file: bool) -> void
      def initialize(project, located, id:, whole_file: false)
        @project = project
        @located = located
        @span = located.span(whole_file:) #: LineSpan
        @id = id
        freeze
      end

      # The ids of members of its own map whose text shares a line with the located member, which is not among
      # them. A member of another map may have the same id and is another member, so elsewhere keeps it.
      #: (Array[Member]) -> Array[String]
      def ids_in(members)
        sharing(others(members)).map { |member, _found| member.id }
      end

      # The ids of members whose text spans exactly the located member's first and last lines, so the agent sees
      # it may be mapping the same lines twice. Equal lines are not equal text: a passage can end within
      # its last line.
      #: (Array[Member]) -> Array[String]
      def same_lines_ids_in(members)
        sharing(others(members)).filter_map { |member, found| member.id if same_lines?(found) }
      end

      # The members sharing a line with the located one, beside map, its own: those in map, those of them on exactly
      # its lines, and those in the other maps, as plain values, with whether the agent should check the text where
      # one of those holds the other's lines without being a whole file.
      #: (Principle)
      #|  -> { overlaps: Array[String], same_lines_as: Array[String], mapped_elsewhere: Array[Hash[String, untyped]],
      #|       text_check: bool }
      def facts_beside(map)
        others = elsewhere(except: map.id)
        members = map.members.to_a
        { overlaps: ids_in(members), same_lines_as: same_lines_ids_in(members),
          mapped_elsewhere: others.shown, text_check: others.text_check_needed? }
      end

      # Each member of a map other than except whose text shares a line with the located member, with its map, its
      # role there and its lines, so the agent sees that one edit changes both, checks the roles fit and how
      # much of the located member it holds, which no other part of the page shows: same_lines when it spans
      # exactly the located member's lines, spans_these_lines when its lines include all of them, and
      # within_these_lines when they include all of its, so the agent can tell which member an edit reaches. A
      # partial overlap is marked neither way. A map that cannot be read is left out; list-member-problems
      # reports it.
      #: (except: String) -> MembersElsewhere
      def elsewhere(except:)
        maps = @project.principles
        MembersElsewhere.new((maps.ids - [except]).flat_map { |id| sharing_in(maps, id) })
      end

      private

      # The members of map id sharing a line with the located member, or none when that map cannot be read.
      #: (MappedPrinciples, String) -> Array[MemberElsewhere]
      def sharing_in(maps, id)
        sharing(maps.find(id).members.to_a).map do |member, found|
          MemberElsewhere.new(principle_id: id, member:, span: found.span(whole_file: member.whole_file?),
                              located: @span)
        end
      rescue Error
        []
      end

      # Each member that shares a line with the located member, with where it is found now: in the same file, by
      # its own path or through a symbolic link.
      #: (Array[Member]) -> Array[[Member, LocatedText]]
      def sharing(members)
        members.filter_map do |member|
          next unless @project.same_file?(member.path, @located.path)

          found = @project.located_text(member.locator)
          [member, found] if found.span.shares_a_line_with?(@span)
        rescue Error
          nil
        end
      end

      # The members of its own map but the located one.
      #: (Array[Member]) -> Array[Member]
      def others(members)
        members.reject { |member| member.id == @id }
      end

      #: (LocatedText) -> bool
      def same_lines?(found)
        found.span.same_lines_as?(@span)
      end
    end
  end
end

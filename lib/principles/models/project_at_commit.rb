# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../data/repository"
require_relative "../data/project_files"
require_relative "member"
require_relative "member_file"
require_relative "principle_members"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The project as one commit holds it: each file's text there, read in the file a path's links lead to, since git
    # holds a link as its target's name, and the lines each member's locator finds in that text.
    class ProjectAtCommit
      #: (Data::Repository, Data::ProjectFiles, String) -> void
      def initialize(repository, files, commit)
        @repository = repository
        @files = files
        @commit = commit
        freeze
      end

      # path's text at the commit, or nil when the commit does not hold it.
      #: (String) -> String?
      def text(path) = @repository.text_at(@commit, @files.leads_to(path))

      # The lines of the member at locator in its file at the commit, or nil when the commit lacks the file or the
      # locator finds nothing in its text there, as after a move; any other refusal still refuses.
      #: (Locator) -> Array[String]?
      def lines(locator)
        path = locator.path
        found = text(path) or return nil
        MemberFile.for(path: path, text: found).lines_of(locator)
      rescue Error => e
        raise unless MemberFile::PLACEMENT_REFUSALS.include?(e.payload.fetch("code"))

        nil
      end

      # Each member's id and the hash of its text at the commit, or nil when the commit lacks a member's file or the
      # member's place in it.
      #: (PrincipleMembers) -> Hash[String, String]?
      def hashes(members)
        members.to_h do |member|
          path = member.path
          found = text(path)
          return nil unless found

          [member.id, MemberFile.for(path: path, text: found).locate(member.locator).sha256]
        end
      rescue Error
        nil
      end

      # Each member's key and the hash of its text at the commit, leaving out a member the commit cannot find.
      #: (Array[Hash[String, untyped]]) -> Hash[String, String]
      def hashes_by_key(members)
        members.map { |fields| Member.new(fields) }.each_with_object({}) do |member, found|
          path = member.path
          committed = text(path) or next
          found[member.key] = MemberFile.for(path: path, text: committed).locate(member.locator).sha256
        rescue Error
          next
        end
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The other maps holding a new whole-file member's file whole too, by its own path or through a link, so a hub
    # file mapped whole into several principles is seen as it is mapped.
    class MapsHoldingFileWhole
      #: (Project, Member) -> void
      def initialize(project, member)
        @project = project
        @member = member
        freeze
      end

      # The ids of the maps other than except holding the file whole; none when the member is a passage. A map that
      # cannot be read is left out, since list-member-problems reports it.
      #: (except: String) -> Array[String]
      def elsewhere(except:)
        return [] unless @member.whole_file?

        maps = @project.principles
        (maps.ids - [except]).select { |id| holds_whole?(maps, id) }
      end

      private

      #: (MappedPrinciples, String) -> bool
      def holds_whole?(maps, id)
        maps.find(id).members.to_a.any? do |member|
          member.whole_file? && @project.same_file?(member.path, @member.path)
        end
      rescue Error
        false
      end
    end
  end
end

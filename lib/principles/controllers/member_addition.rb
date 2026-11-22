# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/member"
require_relative "../models/members_in_consecutive_sections"
require_relative "../models/member_loading_scopes"
require_relative "../views/map_added_to"
require_relative "../views/consecutive_sections_elsewhere"
require_relative "../views/new_loading_scope"

module Principles
  module Controllers
    # A located new member and its before-save map, with reminder facts captured before the map is written.
    class MemberAddition < Command
      #: (Models::Project, tool: RunningTool, map: Models::Principle, member: Hash[String, untyped]) -> void
      def initialize(project, tool:, map:, member:)
        super(project, tool: tool)
        @map = map
        @member = Models::Member.new(member) #: Models::Member
        @joined = joined #: Views::MapAddedTo
      end

      # Locate and report the added member after the caller saved exactly its new map.
      #: (Views::PrintedPrinciple, added_to: Models::Principle) -> Hash[String, untyped]
      def printed(principle, added_to:)
        added = located_member
        shared = lines_shared(@member, @map)
        joined = joined_for(added_to)
        sections = Models::MembersInConsecutiveSections.new(@project, @member).elsewhere(except: @map.id)
        consecutive = Views::ConsecutiveSectionsElsewhere.new(sections)
        map_result.member_added(principle, added: added, shared: shared, joined: joined, consecutive: consecutive)
      end

      private

      # The updated map's after-save context, keeping the reminder facts captured before the write.
      #: (Models::Principle) -> Views::MapAddedTo
      def joined_for(added_to)
        no_completed = @audit_records.known_no_completed_audit?(@map.id)
        joined = @joined.with_completeness_question(
          asks: added_to.members.asks_about_completeness?(no_completed_audit: no_completed)
        )
        scopes = Models::MemberLoadingScopes.new(@project.member_loads(added_to.members))
        joined.with_loading_scope(Views::NewLoadingScope.new(scopes.introduced_by(@member.id)))
      end

      # The new member's id, current lines, the line its paragraph or list item runs on to when it maps only the
      # first, and its stored check, located only after its map was saved.
      #: () -> Hash[String, untyped]
      def located_member
        continues = @project.continues_to(@member.locator)
        { "id" => @member.id }.merge(snapshot(@member.locator).lines)
                              .merge(continues ? { "continues_to_line" => continues } : {})
                              .merge(@member.to_h.slice("check"))
      end

      # The history must inspect the old map before the write, so a batch repeats its reminders only once.
      #: () -> Views::MapAddedTo
      def joined
        history = principle_history(@map.id)
        Views::MapAddedTo.new(keeps_others_held: @map.keeps_others_held?,
                              correction_may_be_open: history.startable_at_head?,
                              reminded: history.first_add_since_commit?(@map))
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "principle"
require_relative "member_moves"
require_relative "declared_member_removals"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The changes a correction declares it made to the map after the audit began: the members it moved,
    # and the members whose role or check a fix changed, which each fixed disposition lists in
    # changed_map_entries, and the members fixed dispositions removed. This tool checks them against the
    # map at the base commit, which may also hold
    # members added since, needing no declaration, as a fix maps a member a finding said was missing (T69); whether a
    # change fixes its finding is the agent's judgement.
    class DeclaredMapChanges
      # The answer's moved_members and each disposition's changed_map_entries and removed_members.
      #: (untyped) -> DeclaredMapChanges
      def self.declared_in(response)
        new(MemberMoves.new(response["moved_members"]), response["dispositions"])
      end

      #: (MemberMoves, untyped) -> void
      def initialize(moves, dispositions)
        @moves = moves
        @entries = claimed(dispositions) #: Array[String]
        @removals = DeclaredMemberRemovals.new(dispositions) #: DeclaredMemberRemovals
        freeze
      end

      #: () -> bool
      def empty?
        @moves.empty? && @entries.empty? && @removals.empty?
      end

      # The base commit, to read there the map the audit began from, or nil when nothing is declared and current is
      # still at map_version, the version the audit began from. Outside git, a map that changed is refused, as are
      # declared changes, since there is no base map to check them against.
      #: (String?, Principle, map_version: String, map_file: String) -> String?
      def base_to_read(base, current, map_version:, map_file:)
        return check_in_git(base, principle_id: current.id) unless empty?
        return if current.version == map_version
        return base if base

        raise stale_map(current.id, map_file)
      end

      # Refuses declared changes outside git, where there is no base map to check them against.
      #: (String?, principle_id: String) -> String
      def check_in_git(base, principle_id:)
        return @moves.check_in_git(base, principle_id: principle_id) unless @moves.empty?
        return base if base

        raise Error.new("map_entries_need_git",
                        "Declared role/check changes and member removals need git, to read the map " \
                        "#{principle_id} began from",
                        "Outside git, defer the finding, commit nothing, and start a fresh audit: " \
                        "#{Error::EXECUTABLE} start-audit #{principle_id}")
      end

      # Refuses unless base is the map the audit began from and current is base with exactly the declared
      # members removed or moved, the claimed members' role and check changed, and any members added (T69).
      #: (Principle, Principle, map_version: String, map_file: String) -> void
      def check(base, current, map_version:, map_file:)
        raise unexplained(current.id, map_file) unless base.version == map_version

        @removals.check_conflicts(@moves, @entries)
        raise unexplained(current.id, map_file) unless reconstructed(base, current).version == current.version

        @removals.check_endpoint(current)
      end

      # Each claimed member's role and check, as was and now, where they differ between the base map with the
      # declared moves applied, which check compares, and current. The block gives [base, current], and is
      # called only when a fix claims an entry, so nothing else reads the base map.
      #: () { () -> [Principle, Principle] } -> Array[Hash[String, untyped]]
      def entry_changes(&)
        return [] if @entries.empty?

        base, current = yield
        moved = @moves.applied(base, current)
        @entries.map { |id| changed_fields(id, moved.member(id), current.member(id)) }
      end

      # The map file, when the correction moved a member in it, even under its own id, a fix changed a
      # member's role or check in it, or added/removed members in it, so the agent commits it too.
      #: (String, ?added: Array[String]) -> Array[String]
      def files_to_commit(map_file, added: [])
        empty? && added.empty? ? [] : [map_file]
      end

      private

      # Replay removals, then moves and role/check changes, then include members added during the correction.
      #: (Principle, Principle) -> Principle
      def reconstructed(base, current)
        retained = @removals.applied(base, current)
        expected = @entries.reduce(@moves.applied(retained, current)) { |map, id| claimed_entry(map, current, id) }
        with_added(expected, current)
      end

      # expected with each member of current whose id it lacks added, as add-member adds it.
      #: (Principle, Principle) -> Principle
      def with_added(expected, current)
        added = current.members.ids - expected.members.ids
        added.reduce(expected) { |map, id| map.adding(current.member(id)) }
      end

      #: (untyped) -> Array[String]
      def claimed(dispositions)
        Array(dispositions).flat_map { |each| each.is_a?(Hash) ? Array(each["changed_map_entries"]) : [] }.uniq
      end

      # The map with the claimed member's role and check as current holds them, refused when they are as
      # they were at the base commit.
      #: (Principle, Principle, String) -> Principle
      def claimed_entry(map, current, id)
        unless current.members.taken?(id)
          raise Error.new("unknown_member", "#{id} is not a member of #{current.id}",
                          "Name in changed_map_entries an id that this command lists: " \
                          "#{Error::EXECUTABLE} show-principle #{current.id}")
        end
        return replayed(map, id, current.member(id)) unless as_at_base?(map, current, id)

        raise Error.new("claimed_change_missing", "#{id}'s role and check did not change during this audit",
                        "The role and check of #{id} are as they were at the base commit; remove it from " \
                        "changed_map_entries.")
      end

      # The map with the member's role and check changed to now's, as change-member-role, change-member-check
      # and remove-member-check changed them.
      #: (Principle, String, Hash[String, untyped]) -> Principle
      def replayed(map, id, now)
        roled = map.changing_role(id, now.fetch("role"))
        return roled.changing_check(id, now.fetch("check")) if now.key?("check")

        roled.member(id).key?("check") ? roled.removing_check(id) : roled
      end

      #: (String, Hash[String, untyped], Hash[String, untyped]) -> Hash[String, untyped]
      def changed_fields(id, was, now)
        changed = %w[role check].reject { |field| was[field] == now[field] }
        { "member_id" => id, **changed.to_h { |field| [field, { "was" => was[field], "now" => now[field] }] } }
      end

      #: (Principle, Principle, String) -> bool
      def as_at_base?(map, current, id)
        map.member(id).slice("role", "check") == current.member(id).slice("role", "check")
      end

      #: (String, String) -> Error
      def unexplained(principle_id, map_file)
        @moves.empty? ? stale_map(principle_id, map_file) : @moves.undeclared(principle_id, map_file)
      end

      #: (String, String) -> Error
      def stale_map(principle_id, map_file)
        Error.new("stale_map", "The map of #{principle_id} changed during this audit",
                  "If you moved a member to fix a finding, declare it in the answer's moved_members as " \
                  "{\"from\": OLD_ID, \"to\": NEW_ID}, and a move that kept its id, as narrowing or widening a " \
                  "passage, as {\"from\": ID, \"to\": ID}; if a fix changed a member's role or check, list the " \
                  "member's id in that fixed disposition's changed_map_entries. If a fix removed a member with " \
                  "remove-member, list its original id in that fixed disposition's removed_members. " \
                  "In git, a member you added with " \
                  "add-member needs no declaration, as long as nothing else changed.\n" \
                  "Otherwise, start a fresh audit: #{Error::EXECUTABLE} start-audit #{principle_id}", map_file)
      end
    end
  end
end

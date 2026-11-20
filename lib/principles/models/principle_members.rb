# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member"
require_relative "misspelt_member_id"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # One principle's members, as Members: finding one by its id, and the rules on ids and keys among them,
    # which Principle asks as it changes the map. It is Enumerable over its members, in the map's order.
    #: [out Elem = Member]
    class PrincipleMembers
      include Enumerable

      # The principle whose members these are.
      #: String
      attr_reader :principle_id

      #: (String, Array[Member]) -> void
      def initialize(principle_id, list)
        @principle_id = principle_id
        @list = list.freeze #: Array[Member]
        freeze
      end

      # Each member, in the map's order, which every Enumerable method iterates.
      # @override
      #: () { (Member) -> void } -> void
      def each(&) = @list.each(&)

      # The members as the frozen list they are held in, without the copy Enumerable#to_a would make.
      #: () -> Array[Member]
      def to_a = @list

      # Whether there are none, as in a map with no members yet.
      #: () -> bool
      def empty? = @list.empty?

      # Each member's id, in the map's order.
      #: () -> Array[String]
      def ids = @list.map(&:id)

      # Each member's key, in the map's order: its stored key, or its id when it has none.
      #: () -> Array[String]
      def keys = @list.map(&:key)

      # Each member by its id.
      #: () -> Hash[String, Member]
      def by_id = @list.to_h { |member| [member.id, member] }

      # Each part of principles an upgrade can change that a member is, as Member#package_part names it from the
      # project's hooks and, when it asks, the text of a member the block gives, once.
      #: (HookCommands) { (Member) -> String } -> Array[String]
      def package_parts(hooks, &text_of)
        @list.filter_map { |member| member.package_part(hooks) { text_of.call(member) } }.uniq
      end

      # Each file a member is in, once, in the map's order.
      #: () -> Array[String]
      def paths = @list.map(&:path).uniq

      # Each member in one of paths, in the map's order.
      #: (Array[String]) -> Array[Member]
      def in_files(paths) = @list.select { |member| paths.include?(member.path) }

      # Each member in one of paths, by its id and path, as show-meta-principle-passage reports the members already in
      # an entry file, which the agent judges against the passage.
      #: (Array[String]) -> Array[Hash[String, String]]
      def members_in(paths)
        in_files(paths).map { |member| { "id" => member.id, "path" => member.path } }
      end

      # A small first map prompts an agent question, not a minimum member count or a verdict of incompleteness.
      # no_completed_audit is known absence from the record owner; false also covers unknown state.
      #: (no_completed_audit: bool) -> bool
      def asks_about_completeness?(no_completed_audit:)
        (1..2).cover?(count) && no_completed_audit
      end

      # The member with member_id now, or nil when none has it.
      #: (untyped) -> Member?
      def with_id(member_id) = @list.find { |member| member.id == member_id }

      # The member known by key, its id before its first move or its id when it never moved, or nil when none is.
      # The first is the only one, since a map whose members share a key is refused (repeated_keys).
      #: (String) -> Member?
      def with_key(key) = @list.find { |member| member.key == key }

      # The check of the member with member_id, or nil when it has none or no member has that id.
      #: (untyped) -> String?
      def check(member_id) = with_id(member_id)&.check

      # The id of each member that names a check, in the map's order.
      #: () -> Array[String]
      def checked_ids = @list.select(&:check).map(&:id)

      # Whether a member has member_id and names no check, so its assessment takes no check_result.
      #: (untyped) -> bool
      def unchecked?(member_id)
        member = with_id(member_id)
        !member.nil? && member.check.nil?
      end

      # Each key more than one member is known by, a member with no stored key being known by its id, with the ids of
      # the members that share it. An audit record files each member under its key, so one would stand for the other.
      #: () -> Hash[String, Array[String]]
      def repeated_keys
        @list.group_by(&:key).select { |_, sharing| sharing.length > 1 }.transform_values { it.map(&:id) }
      end

      # Refuses these members when two share an id or a key, as a hand edit or a merge can leave them. where names the
      # map as read, and file the map file the refusal points at.
      #: (where: String, file: String) -> void
      def refuse_repeats(where:, file:)
        refuse_repeated_ids(where, file)
        refuse_repeated_keys(where, file)
      end

      # Each member's key by id, for the members whose key is not their id because they have moved.
      #: () -> Hash[String, String]
      def moved_keys = @list.to_h { |member| [member.id, member.key] }.reject { |id, key| id == key }

      # The member with member_id, refused unless one has it.
      #: (String) -> Member
      def found(member_id)
        with_id(member_id) || raise(unknown(member_id))
      end

      #: (String) -> bool
      def taken?(member_id) = !with_id(member_id).nil?

      # member, with a key of its own when its id is already the key of a member that moved away from there;
      # otherwise the new member would inherit that member's audit.
      #: (Member) -> Member
      def keyed(member)
        return member unless keys.include?(member.id)

        free = (2..).lazy.map { |n| "#{member.id}~#{n}" }.find { |key| !keys.include?(key) }
        member.keyed_as(free || raise(KeyError, "no free key for #{member.id}"))
      end

      # The refusal for an id no member has now, naming the member that had it before it moved, since a member keeps
      # its id from before its first move as its key. A member moved twice is not found by its middle id.
      #: (String) -> Error
      def unknown(member_id)
        ids = "To see each member's id: #{Error::EXECUTABLE} show-principle #{@principle_id}"
        moved = @list.select { |each| each.key == member_id }
        return misspelt(member_id, ids) unless moved.one?

        now = moved.fetch(0).id
        Error.new("unknown_member", "#{member_id} is not a member of #{@principle_id}: it moved, and its id is now " \
                                    "#{now}", "Give its id now, #{now}, in place of #{member_id}.\n#{ids}")
      end

      # The refusal for an id no member has or had, naming the one mapped id it is spelled like apart from case and
      # punctuation, if any, under did_you_mean, so the controller can print the command again with it. The near miss
      # itself is never accepted.
      #: (String, String) -> Error
      def misspelt(member_id, ids)
        unknown = "#{member_id} is not a member of #{@principle_id}"
        closest = MisspeltMemberId.new(member_id).closest(@list.map(&:id))
        return Error.new("unknown_member", unknown, ids) unless closest

        Error.new("unknown_member", "#{unknown}; did you mean #{closest}?", ids).including("did_you_mean" => closest)
      end

      # The oldest map format that holds every member: 1 unless a member uses a later field.
      #: () -> Integer
      def format = @list.map(&:map_format).max || 1

      private

      # The ids more than one member has, which a hand edit or a merge can leave.
      #: () -> Array[String]
      def repeated_ids = @list.map(&:id).tally.select { |_, count| count > 1 }.keys

      # Every member is found and recorded by its id, so of two sharing one, one would silently stand for both.
      #: (String, String) -> void
      def refuse_repeated_ids(where, file)
        shared = repeated_ids
        return if shared.empty?

        raise Error.new("duplicate_member", "#{where} has more than one member with id #{shared.join(", ")}",
                        "Keep one of each: edit the map file so that no two members point at the same place, " \
                        "then commit it.", file)
      end

      # Two members with ids of their own known by one key: which keeps it decides which keeps the audit filed
      # under it, so the repair leaves that to the agent.
      #: (String, String) -> void
      def refuse_repeated_keys(where, file)
        key, ids = repeated_keys.first
        return unless ids

        raise Error.new("duplicate_member", "#{where} has more than one member known by key #{key}: #{ids.join(", ")}",
                        "Keep one key per member: the member that keeps #{key} keeps the audit filed under it, so " \
                        "give the other a key of its own, such as #{key}~2, then commit the map.", file)
      end
    end
  end
end

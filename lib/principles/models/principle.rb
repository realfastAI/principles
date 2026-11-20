# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"
require_relative "../data/schema_check"
require_relative "../data/map_files"
require_relative "member"
require_relative "principle_members"
require_relative "activation"
require_relative "json_digest"
require_relative "meta_principle"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One principle: its id, description and activation, and the members that reinforce it, each a project file
    # or a place in one, with the role it plays. Its map file holds it. Every change returns a new principle and
    # leaves this one as it was; MappedPrinciples saves it. Fields its map holds beyond these are kept as they are.
    class Principle
      #: String
      attr_reader :id

      # A parsed map validates repeated member identities beside the member state it constructs.
      #: (String, Hash[String, untyped], files: Data::MapFiles, ?commit: String?) -> Principle
      def self.from_map(id, fields, files:, commit: nil)
        map = new(id, fields)
        where = commit ? "#{files.relative(map.id)} at commit #{commit[0, 12]}" : files.relative(map.id)
        map.members.refuse_repeats(where: where, file: files.relative(map.id))
        map
      end

      #: (String, Hash[String, untyped]) -> void
      def initialize(id, fields)
        @id = id
        # The principle owns its data: every field, an unknown one too, is copied and frozen down to each string, so
        # no change made in place to what it was built from or what it hands out changes its file or version. The copy
        # goes through the JSON its version digests, which a map's file holds anyway.
        owned = JSON.parse(JSON.generate(fields), freeze: true) #: Hash[String, untyped]
        @members = PrincipleMembers.new(id, owned.fetch("members").map { |each| Member.new(each) }) #: PrincipleMembers
        @fields = owned.merge("members" => @members.map(&:to_h).freeze).freeze #: Hash[String, untyped]
        freeze
      end

      #: () -> untyped
      def description
        @fields["description"]
      end

      # Its identity and stated rule, for a listing that compares principles without their members.
      #: () -> Hash[String, untyped]
      def description_with_id = { "id" => @id, "description" => description }

      # Its members as Member values, which say each one's id, key, place and check.
      #: PrincipleMembers
      attr_reader :members

      # Whether this principle's audit keeps the release of principles it ran under, and its next full audit states
      # what changed since: only the meta-principle's, which judges whether the keeping that release ships still
      # works.
      #: () -> bool
      def keeps_package? = meta_principle?

      # Whether this principle's full audit states which other principles have members no audit has judged as they
      # are now: only the meta-principle's, whose members are meant to bring those changes to an audit.
      #: () -> bool
      def keeps_others_held? = meta_principle?

      # Whether this is the meta-principle with no members, as a setup that wrote its map before the first
      # member, or removing its last member, leaves it. Only this principle's having none is out of the way: setup no
      # longer writes it, and its first add-member creates it with that member (T74), while any other principle has
      # none from create-principle until its first add-member.
      #: () -> bool
      def unstarted? = meta_principle? && @members.empty?

      # Whether a full audit of this principle can have started, so that a correction may be open while a member is
      # added: start-audit refuses a map with no members.
      #: () -> bool
      def auditable? = !@members.empty?

      # The map's version: the digest of what its JSON says, so any change to it gives a new version, and a hand
      # edit or a formatter that only reorders its keys does not.
      #: () -> String
      def version = JsonDigest.new(@fields).to_s

      # Whether other would write the same file as this principle, so saving it would change nothing.
      #: (Principle) -> bool
      def same_as?(other) = version == other.version

      # Each member as this tool prints it: its id beside the fields shown gives it.
      #: () -> Array[Hash[String, untyped]]
      def members_shown
        @members.zip(shown.fetch("members")).map { |member, fields| { "id" => member.id }.merge(fields) }
      end

      # The map as its file holds it.
      #: () -> Hash[String, untyped]
      def to_h
        @fields
      end

      # The member with member_id, refused unless this principle has it.
      #: (String) -> Hash[String, untyped]
      def member(member_id)
        @members.found(member_id).to_h
      end

      #: (String) -> Principle
      def describing(description)
        Principle.new(id, @fields.merge("description" => description))
      end

      # When the agent said this principle's work is in hand, as the map stores it, or nil when it has not.
      #: () -> Hash[String, untyped]?
      def activation = @fields["activation"]

      #: (Activation) -> Principle
      def activating(activation) = Principle.new(id, @fields.merge("activation" => activation.to_h))

      # This principle with member added, refused when it already has a member with its id.
      #: (Hash[String, untyped]) -> Principle
      def adding(member)
        added = Member.new(member)
        new_id = added.id
        if @members.taken?(new_id)
          raise taken(new_id, repair("To change its role", "change-member-role", new_id, "--role ROLE"),
                      repair("To point it elsewhere", "move-member", new_id, added.move_placeholders))
        end

        with_members(@members.to_a + [@members.keyed(added)])
      end

      # This principle with member_id pointed at the place located names, in the same file. The new place replaces
      # the old one whole, and every other field is kept: its role, and any a newer version wrote. It is
      # refused when another member is already there.
      #: (String, Hash[String, untyped]) -> Principle
      def moving(member_id, located)
        old = @members.found(member_id)
        moved = old.moved_to(located)
        new_id = moved.id
        if new_id != member_id && @members.taken?(new_id)
          raise taken(new_id, repair("To remove one of them", "remove-member", member_id))
        end

        replacing(old, moved)
      end

      #: (String, String) -> Principle
      def changing_role(member_id, role) = changing(member_id, "role" => role)

      # Names the command that enforces a member, which an audit asks the agent to run. This tool
      # stores it and never runs it.
      #: (String, String) -> Principle
      def changing_check(member_id, check) = changing(member_id, "check" => check)

      #: (String) -> Principle
      def removing_check(member_id)
        old = @members.found(member_id)
        unless old.to_h.key?("check")
          raise Error.new("no_check", "#{member_id} has no check in #{id}",
                          "To see each member's check: #{Error::EXECUTABLE} show-principle #{id}")
        end

        replacing(old, old.without_check)
      end

      #: (String) -> Principle
      def removing(member_id)
        old = @members.found(member_id)
        with_members(@members.reject { |each| each.equal?(old) })
      end

      # Member owns the format each member field needs; this name stays while principle_spec checks it there.
      FIELD_FORMATS = Member::FIELD_FORMATS #: Hash[String, Integer]

      # The oldest format that holds every member of this principle: 1 unless a member uses a later field.
      #: () -> Integer
      def format
        @members.format
      end

      private

      # Whether this is the principle that keeps every other one held.
      #: () -> bool
      def meta_principle? = @id == MetaPrinciple::ID

      # This principle with only the fields this tool knows, for printing: a field someone added to the file is kept
      # in it but never shown as if this tool had said it.
      #: () -> Hash[String, untyped]
      def shown
        Data::SchemaCheck.new("member-map").known(@fields)
      end

      # The refusal for a member id another member of this principle has, ending with its repairs.
      #: (String, *Error::RepairCommand) -> Error
      def taken(new_id, *repairs)
        Error.new("member_exists", "#{new_id} is already a member of #{id}", "").ending_with(repairs)
      end

      # A repair command acting on a member of this principle, with the placeholders the agent fills; the controller
      # prints it, quoting the member.
      #: (String, String, String, ?String?) -> Error::RepairCommand
      def repair(purpose, command, member, usage = nil)
        Error::RepairCommand.new(purpose: purpose, command: command, values: [id, member], usage: usage)
      end

      # This principle with member_id's entry holding fields in place of its own.
      #: (String, Hash[String, untyped]) -> Principle
      def changing(member_id, fields)
        old = @members.found(member_id)
        replacing(old, old.with(fields))
      end

      #: (Member, Member) -> Principle
      def replacing(old, member)
        with_members(@members.map { |each| each.equal?(old) ? member : each })
      end

      # Members are kept in id order, so a map's file changes only where a member does.
      # Its format is worked out again, and written only above 1, so a map that uses no later field keeps
      # the bytes an older version wrote, and its version.
      #: (Array[Member]) -> Principle
      def with_members(list)
        changed = Principle.new(id, @fields.merge("members" => list.sort_by(&:id).map(&:to_h)))
        fields = changed.to_h.except("format")
        Principle.new(id, changed.format > 1 ? fields.merge("format" => changed.format) : fields)
      end
    end
  end
end

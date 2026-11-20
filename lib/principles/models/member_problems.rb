# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "acknowledgement_refusal"
require_relative "audit_record"
require_relative "principle_members"
require_relative "principle_history"
require_relative "principle_mapping_history"
require_relative "member_state"
require_relative "locate_refusal"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # One map's members, each as broken, changed, unchanged, unchanged since its mapping commit or with no
    # baseline, against what this tool last knew of its text: the last audit's hash for it, or else its text at
    # the commit that mapped it where it is.
    # A member is changed only when its own text changed, so an edit elsewhere in its file is not one.
    class MemberProblems
      # What this tool last knew of each member's text, by key: the last audit's hashes and the commit it began
      # from, and each member's hash and commit at the commit that mapped it where it is.
      class Baselines
        # The last audit's hashes for members' map, and each member's hash and commit at the commit that mapped it
        # where it is, read with the map as that commit held it; none outside git.
        #: (Project, PrincipleMembers, ?mapping: PrincipleMappingHistory?) -> Baselines
        def self.of(project, members, mapping: nil)
          records = project.audit_records
          mapped = mapped_where_it_is(project, members, mapping: mapping)
          new(audit: records.readable(members.principle_id), mapped: mapped, in_git: project.history.inside_git?,
              hashes: records.hashes_to_compare(members.principle_id), mapping: mapping)
        end

        # Each member's hash and commit at the commit that mapped it where it is, read with the map as that commit
        # held it.
        #: (Project, PrincipleMembers, ?mapping: PrincipleMappingHistory?) -> Hash[String, Hash[String, String]]
        def self.mapped_where_it_is(project, members, mapping: nil)
          project.principle_history(members.principle_id, mapping: mapping).mapped_baselines(members.keys)
        end

        # Whether the project is in git, so a member with no baseline is one no commit holds yet.
        #: bool
        attr_reader :in_git

        # Whether a later copy wrote the principle's record, so its audits and acknowledgements wait on an upgrade.
        #: () -> bool
        def waiting? = @hashes.waiting?

        # audit is the principle's audit record, if any: its hashes, the commit it began from and whether it is
        # completed, so a one-member audit is offered only where one would be accepted. hashes is the member
        # hashes the record holds, which a later copy may have written, so its members are compared read-only.
        #: (audit: AuditRecord?, mapped: Hash[String, Hash[String, String]], in_git: bool,
        #|  ?hashes: RecordedHashes, ?mapping: PrincipleMappingHistory?) -> void
        def initialize(audit:, mapped:, in_git:, hashes: audit&.members&.hashes || RecordedHashes::NONE, mapping: nil)
          @hashes = hashes
          @audit = audit #: AuditRecord?
          @audit_base = audit&.base_commit #: String?
          @mapped = mapped
          @in_git = in_git
          @mapping = mapping #: PrincipleMappingHistory?
          freeze
        end

        # Only a mapping baseline supplies automatic history; a recorded hash needs its own provenance.
        #: (String) -> PrincipleMappingHistory?
        def mapping_for(key)
          return if @hashes.hash_for(key)

          @mapping if @mapped.key?(key)
        end

        # The hash this tool last knew for the member known by key, and what it was: the last audit's, or else its
        # hash at the commit that mapped it, with why no audit gave one; neither when it has no baseline.
        #: (String) -> [String?, Hash[String, untyped]?]
        def of(key)
          if (audited = @hashes.hash_for(key))
            [audited, { "baseline" => "audit", "commit" => @audit_base }]
          elsif @mapped.key?(key)
            mapped = @mapped.fetch(key)
            [mapped.fetch("sha256"), { "baseline" => "mapping_commit", "commit" => mapped.fetch("commit"),
                                       "no_audit_because" => @hashes.empty? ? "no_audit_record" : "not_in_last_audit" }]
          else
            [nil, nil]
          end
        end

        # Why a member these baselines do not hold has none: in git no commit holds it where its map places
        # it, and outside git there is no history.
        #: () -> String
        def none_because = @in_git ? "not_committed" : "outside_git"

        # Whether no full audit of the principle has completed: it has no record, or an open one that keeps none.
        #: () -> bool
        def no_completed_audit?
          audit = @audit
          audit.nil? || audit.last_completed.nil?
        end

        # Whether a one-member audit may judge member's change to now_sha256: in git, and where the audit record gives
        # no refusal, which Acknowledgement refuses by too, so list-member-problems offers no command certain to be
        # refused.
        #: (Member, String?) -> bool
        def acknowledgeable?(member, now_sha256)
          audit = @audit
          @in_git && !waiting? && !audit.nil? && AcknowledgementRefusal.of(audit, member, now_sha256:).nil?
        end
      end

      # One map's members in project against what this tool last knew of each. A map that cannot be read is
      # refused when it was asked for, and listed as broken among every map.
      #: (Project, String, ?listing_all: bool) -> MemberProblems
      def self.for(project, id, listing_all: false)
        map = project.principles.find(id)
        members = map.members
        mapping = PrincipleMappingHistory.load_if_linked(current: map, project: project)
        new(members: members, now: project.current_by_key(members),
            baselines: Baselines.of(project, members, mapping: mapping))
      rescue Error => e
        raise unless listing_all

        none = PrincipleMembers.new(id, [])
        new(members: none, now: {}, baselines: Baselines.of(project, none), unreadable: e.payload)
      end

      # now holds, for each member by key, its hash now or the refusal that says why it cannot be found.
      # unreadable is the refusal for a map this tool could not read, which is listed as one broken entry.
      #: (members: PrincipleMembers, now: Hash[String, untyped],
      #|  baselines: Baselines, ?unreadable: Hash[String, untyped]?) -> void
      def initialize(members:, now:, baselines:, unreadable: nil)
        @members = members
        @now = now
        @baselines = baselines
        @unreadable = unreadable
        freeze
      end

      # Every member as one entry: its map, id and state, and for a changed member what it was compared with.
      #: () -> Array[Hash[String, untyped]]
      def entries
        if @unreadable
          return [{ "principle" => principle_id, "state" => "unreadable_map" }.merge(@unreadable.except("status"))]
        end

        @members.map { |member| entry(member) }
      end

      # The entries whose reference is broken.
      #: () -> Array[Hash[String, untyped]]
      def broken
        entries.select { |each| MemberState::BROKEN.include?(each.fetch("state")) }
      end

      # Whether a member an audit or acknowledgement assessed changed since, rather than only a member edited since
      # the commit that mapped it, which no audit assessed.
      #: () -> bool
      def assessed_change? = assessed_changes.positive?

      # How many such members changed, which the session-start hook counts by principle.
      #: () -> Integer
      def assessed_changes = changes_to_act_on.count { |member| assessed?(member) }

      # How many members no audit has assessed, compared only with the commit that mapped them, edited or not, which
      # --short counts on stdout; none while the principle's audits wait on an upgrade.
      #: () -> Integer
      def never_assessed = @baselines.waiting? ? 0 : compared_with.fetch("mapping_commit", 0)

      # The entries whose own text changed since this tool last knew it, those an audit assessed first. Given a
      # block, each gains "history", what the block makes of its member, the hash it was compared with, and its
      # hash now and the selected automatic history when that mapping supplies its baseline.
      #: () ?{ (Member, String, String, PrincipleMappingHistory?) -> Hash[String, untyped] }
      #| -> Array[Hash[String, untyped]]
      def changed(&history)
        assessed, unassessed = changed_members.partition { |member| assessed?(member) }
        (assessed + unassessed).map do |member|
          history ? history_entry(member, history) : entry(member)
        end
      end

      # Each member in paths whose own text changed or whose reference is now broken, with its state, as a completed
      # audit names them for another map that shares a file the audit's fixes changed.
      #: (Array[String]) -> Array[MemberState]
      def changed_or_broken_in(paths)
        return [] if @unreadable

        @members.in_files(paths).map { |member| MemberState.new(member.id, entry(member).fetch("state")) }
                .select(&:changed_or_broken?)
      end

      # Each member no audit has judged as it is now, by id with its state: changed or broken since what this tool
      # last knew of it, or never assessed, having only its mapping commit or no baseline at all. A map
      # this tool cannot read is one entry, with no id, whose state is unreadable_map.
      #: () -> Array[Hash[String, untyped]]
      def unjudged = entries.reject { it.fetch("state") == "unchanged" }.map { it.slice("id", "state") }

      #: () -> String
      def principle_id = @members.principle_id

      # The ids of the members whose own text changed and whose change a one-member audit may judge on its own, so
      # list-member-problems fills that audit's command for each.
      #: () -> Array[String]
      def acknowledgeable_member_ids
        changed_members.select { |member| @baselines.acknowledgeable?(member, @now[member.key]) }.map(&:id)
      end

      # How many members found in their files were compared with each baseline, audit or mapping_commit, or had
      # none (no_baseline), so an unchanged member compared only with the commit that mapped it is not read as
      # unchanged since an audit.
      #: () -> Hash[String, Integer]
      def compared_with
        return {} if @unreadable

        found = @members.reject { |member| @now[member.key].is_a?(Hash) }
        found.map { |member| baseline(member.key).last&.fetch("baseline") || "no_baseline" }.tally.sort.to_h
      end

      # Whether this readable map has no completed audit, independent of baseline readiness; a newer record is
      # unknown to this copy, rather than evidence that no audit completed.
      #: () -> bool
      def no_completed_audit? = @unreadable.nil? && !@baselines.waiting? && @baselines.no_completed_audit?

      # Whether this readable map has no members, even when an older full audit completed before it was emptied.
      #: () -> bool
      def empty_map? = @unreadable.nil? && @members.empty?

      # Whether the principle awaits its first full audit: none has completed and a member is found, in git one a
      # commit or an open audit gives a baseline, since until a commit holds its map committing gives its members
      # one.
      #: () -> bool
      def awaits_first_audit?
        return false if @baselines.waiting? || !@baselines.no_completed_audit?

        bases = compared_with.keys
        @baselines.in_git ? bases.any? { it != "no_baseline" } : !bases.empty?
      end

      # Why members found in their files have no baseline, or nil when every one has one. Outside git a principle
      # awaiting its first full audit has none either: that audit is the one remedy, which awaits_first_audit? names.
      #: () -> String?
      def no_baseline_because
        return if no_baseline_paths.empty? || (awaits_first_audit? && !@baselines.in_git)

        @baselines.none_because
      end

      # Each file holding a member found with no baseline, once.
      #: () -> Array[String]
      def no_baseline_paths
        return [] if @unreadable

        @members.select { |member| !@now[member.key].is_a?(Hash) && baseline(member.key).last.nil? }
                .map(&:path).uniq
      end

      private

      #: (Member, ^(Member, String, String, PrincipleMappingHistory?) -> Hash[String, untyped]) -> Hash[String, untyped]
      def history_entry(member, history)
        entry(member).merge("history" => history.call(member, baseline(member.key).first.to_s, @now[member.key].to_s,
                                                      @baselines.mapping_for(member.key)))
      end

      # The members whose own text changed since this tool last knew it; none in a map that cannot be read.
      #: () -> Array[Member]
      def changed_members
        return [] if @unreadable

        @members.select { |member| entry(member).fetch("state") == "changed" }
      end

      # The changed members this copy can act on: none while a later copy's record makes them wait on an upgrade,
      # so they give --short neither exit 3 nor 4.
      #: () -> Array[Member]
      def changes_to_act_on = @baselines.waiting? ? [] : changed_members

      #: (Member) -> bool
      def assessed?(member) = baseline(member.key).last&.fetch("baseline") == "audit"

      #: (Member) -> Hash[String, untyped]
      def entry(member)
        listed = { "principle" => principle_id, "id" => member.id }
        now = @now[member.key]
        return compared(listed, member.key, now.to_s) unless now.is_a?(Hash)

        listed.merge("state" => LocateRefusal.new(now).member_state).merge(now.except("status"))
      end

      # listed, compared with the last audit's hash for key, or else with its hash at the commit that mapped it.
      # An unchanged member compared only with the commit that mapped it has never been assessed, so it is
      # counted apart from one an audit assessed: counts is read first, and "unchanged" alone reads as audited.
      #: (Hash[String, untyped], String, String) -> Hash[String, untyped]
      def compared(listed, key, sha)
        then_sha, since = baseline(key)
        return listed.merge("state" => "no_baseline") unless since
        unless then_sha == sha
          return listed.merge("state" => "changed", "since" => since,
                              **(@baselines.waiting? ? { "waiting_on_an_upgrade" => true } : {}))
        end

        listed.merge("state" => since["baseline"] == "mapping_commit" ? "unchanged_since_mapping" : "unchanged")
      end

      #: (String) -> [String?, Hash[String, untyped]?]
      def baseline(key) = @baselines.of(key)
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member"
require_relative "member_history"
require_relative "mapped_principles"
require_relative "placement"
require_relative "project_history"
require_relative "member_mapping_run"
require_relative "principle_mapping_history"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One principle's member mappings, newest first: each key's run ends where a selected map no longer holds it.
    # Supplied certified mapping history selects earlier IDs and refuses unprovable reads. The legacy direct-ID
    # walk stops at unreadable maps, which can only hide an older change.
    class PrincipleHistory
      #: (id: String, history: ProjectHistory, principles: MappedPrinciples, ?mapping: PrincipleMappingHistory?) -> void
      def initialize(id:, history:, principles:, mapping: nil)
        @id = id
        @history = history
        @principles = principles
        @mapping = mapping #: PrincipleMappingHistory?
        freeze
      end

      # A request belongs to this current ID only while its map stayed present since its supplied base.
      # Earlier-ID member history cannot extend a retired current-ID request's lifetime.
      #: (String?) -> void
      def confirm_current_id_since(base)
        return unless base

        paths = [@principles.file(@id), @principles.earlier_file(@id)]
        return if @history.commits_touching_since(base, paths).all? do |commit|
          paths.any? { |path| @history.entry_at?(commit, path) }
        end

        raise Error.new("stale_request", "#{@id}'s map was absent in committed history after this request began",
                        "Start the audit again and answer the new request: #{Error::EXECUTABLE} start-audit #{@id}")
      end

      # Each key's run, newest first, as [commit, the member's fields at that commit]; a key HEAD's map does
      # not hold has an empty run. Each commit's map is read once for every key.
      #: (Array[String]) -> Hash[String, Array[[String, Hash[String, untyped]]]]
      def runs(keys)
        runs = keys.to_h { |key| [key, []] } #: Hash[String, Array[[String, Hash[String, untyped]]]]
        open = keys.dup
        mapping_commits.each do |sha|
          members = members_at(sha) or break
          # A key the map at sha does not hold ends its run.
          open.select! { |key| members.key?(key) && runs.fetch(key).push([sha, members.fetch(key)]) }
          break if open.empty?
        end
        runs
      end

      # Each key's text at the oldest commit of its run that can locate the member, as {"commit", "sha256"};
      # a key with no such commit is left out.
      #: (Array[String]) -> Hash[String, Hash[String, String]]
      def mapped_baselines(keys)
        runs(keys).each_with_object({}) do |(key, run), found|
          baseline = MemberMappingRun.new(key, run).baseline(@history)
          found[key] = baseline if baseline
        end
      end

      # The commits that changed member's own text since baseline, walking the commits that touched this map or
      # any file it has placed the member in, so a move to a renamed file keeps its earlier edits.
      #: (Member, baseline: String, now: String) -> Hash[String, untyped]
      def member_history(member, baseline:, now:)
        key = member.key
        now_at = @principles.find(@id).member(member.id)
        hashes = {} #: Hash[String, String?]
        hash_at = ->(revision) { hashes.fetch(revision) { hashes[revision] = hash_at(key, now_at, revision) } }
        commits = @history.commits_touching([*paths_of(member), *map_paths])
        MemberHistory.new(baseline: baseline, now: now, commits: commits, head: @history.head || "HEAD",
                          hash_at: hash_at).to_h
      end

      # The map as commit holds it, such as the one an audit began from, refused as MappedPrinciples refuses its text;
      # a commit before the folder took its name now holds it under the earlier name, and a commit that lacks
      # the map under both gives empty text, which is refused as unparseable in the legacy path. A supplied
      # mapping history owns strict earlier-ID selection and its refusal outside the proven interval.
      #: (String) -> Principle
      def map_at(commit)
        mapping = @mapping
        return mapping.map_at_revision(commit, captured: @history.captured_head) if mapping

        text = map_paths.lazy.filter_map { |path| @history.text_at(commit, path) }.first
        @principles.parsed(@id, text.to_s, commit: commit)
      end

      # Whether a full audit of this principle can have started from HEAD, so a correction may be open: in git,
      # start-audit refuses a map that is not committed or has no member. False outside git, or when HEAD
      # holds no map it can read.
      #: () -> bool
      def startable_at_head?
        head = @history.head or return false
        map_at(head).auditable?
      rescue PrinciplePublication::ProofError
        raise
      rescue Error
        false
      end

      # Whether an add-member to map, as it stands before the member joins, is the first since the map was last
      # committed, which add-member's reminders print on: map has no member, or, in git, its file is as HEAD
      # holds it. Outside git, only with the first member.
      #: (Principle) -> bool
      def first_add_since_commit?(map)
        return true if map.members.empty?
        return false unless @history.head

        @history.uncommitted([@principles.file(@id)]).empty?
      end

      # The member's fields as the map at commit placed it, found by key; nil where that map did not hold it or cannot
      # be read, so a one-member audit reads a moved member where it was at its baseline.
      #: (String, String) -> Hash[String, untyped]?
      def placed_at(commit, key)
        members_at(commit)&.fetch(key, nil)
      end

      # Where the member with key may be read at since and at each later commit that touched its map or a file the
      # map has placed it in, oldest first: as each commit's map placed it, then as now_at, its entry now, places it.
      # Lazy, so a search for the baseline reads no further than the commit that holds it.
      #: (String, String, Hash[String, untyped]) -> Enumerator::Lazy[Placement]
      def placements_since(since, key, now_at)
        paths = [*paths_of(Member.new(now_at)), *map_paths]
        later = @history.commits_touching(paths, since: since).map { |commit| commit.fetch("sha") }.reverse
        [since, *later].lazy.flat_map { |commit| placements_at(commit, key, now_at) }
      end

      # The paths a change to the member with key from commit to now_at, its entry now, spans: as commit's map placed
      # it, or as now_at does where that map did not hold it, then its path now.
      #: (String, String, Hash[String, untyped]) -> Array[String]
      def paths_from(commit, key, now_at)
        placements_at(commit, key, now_at).fetch(0).paths_to(Member.new(now_at).path)
      end

      private

      #: () -> Array[String]
      def mapping_commits
        @mapping&.revisions&.keys || @history.commits_touching(map_paths).map { |commit| commit.fetch("sha") }
      end

      # Map files used by member history: certified selected IDs, or the legacy current ID, in either folder.
      #: () -> Array[String]
      def map_paths = @mapping&.map_paths || [@principles.file(@id), @principles.earlier_file(@id)]

      # The member's placements at commit, as that commit's map placed it and as now_at does, once each.
      #: (String, String, Hash[String, untyped]) -> Array[Placement]
      def placements_at(commit, key, now_at)
        fields_at = [members_at(commit)&.fetch(key, nil), now_at].compact
        fields_at.uniq { |fields| Member.new(fields).reference }.map do |fields|
          Placement.new(commit: commit, reference: Member.new(fields).reference,
                        sha256: @history.hashes_by_key_at(commit, [fields]).values.first)
        end
      end

      # Every path this map has given member, newest first, from its run back from HEAD.
      #: (Member) -> Array[String]
      def paths_of(member)
        earlier = runs([member.key]).fetch(member.key).map { |_sha, fields| fields.fetch("path") }
        [member.path, *earlier].uniq
      end

      # The hash of the member with key at revision, located as this map at revision places it. Where that map
      # holds the member but its place cannot be found there, as at the commit that renamed its file before the
      # map followed, it is located as now_at, its entry in the map now, places it. nil when the map at revision
      # does not hold it.
      #: (String, Hash[String, untyped], String) -> String?
      def hash_at(key, now_at, revision)
        fields = members_at(revision)&.fetch(key, nil) or return nil
        @history.hashes_by_key_at(revision, [fields])[key] || @history.hashes_by_key_at(revision, [now_at])[key]
      end

      # Each member the map at commit holds, by key. Legacy unreadable maps give nil; certified proof failures
      # remain failures rather than shortening a run or inventing an absent placement.
      #: (String) -> Hash[String, Hash[String, untyped]]?
      def members_at(commit)
        map_at(commit).members.to_h { |member| [member.key, member.to_h] }
      rescue PrinciplePublication::ProofError
        raise
      rescue Error
        nil
      end
    end
  end
end

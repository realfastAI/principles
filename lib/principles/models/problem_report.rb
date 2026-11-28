# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "acknowledgements_to_offer"
require_relative "member_problems"
require_relative "missing_files"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What list-member-problems reports across the maps it reads: refused while any member's reference is
    # broken, so a gate can stop on its exit status alone, and otherwise every changed member and a count of
    # each state.
    class ProblemReport
      # What list-member-problems reports for map id, or every map, listing a map it cannot read among them, with the
      # project's history, which lets each missing file carry the rename git detects for it. Every map's history is
      # read in one walk of git's, not one each.
      #: (Project, String?) -> ProblemReport
      def self.for(project, id)
        maps = if id then [MemberProblems.for(project, id)]
               else every_map(project)
               end
        new(maps, history: project.history)
      end

      # Each map's problems, its history read ahead at the files PrincipleHistory walks for a map, under the folder's
      # name now and its earlier one.
      #: (Project) -> Array[MemberProblems]
      def self.every_map(project)
        ids = project.principles.ids
        project.history.read_ahead(ids.map { [project.principles.file(it), project.principles.earlier_file(it)] })
        ids.map { MemberProblems.for(project, it, listing_all: true) }
      end
      private_class_method :every_map

      # history, when given, lets each missing file carry the rename git detects for it.
      #: (Array[MemberProblems], ?history: ProjectHistory?) -> void
      def initialize(maps, history: nil)
        @maps = maps
        @history = history
        freeze
      end

      # The changed members and the count of each state, refused when any member is broken. Given a block, each
      # changed member gains the history the block makes of its map id, member, baseline hash, hash now and
      # the selected automatic history when its mapping supplies the baseline.
      #: () ?{ (String, Member, String, String, PrincipleMappingHistory?) -> Hash[String, untyped] }
      #| -> Hash[String, untyped]
      def checked(&)
        broken = @maps.flat_map(&:broken)
        refuse(broken) unless broken.empty?

        { "members" => changed(&),
          "counts" => @maps.flat_map(&:entries).map { |each| each.fetch("state") }.tally.sort.to_h,
          "compared_with" => compared_with, **no_baseline_because, **awaiting_first_audit_field, **mapping_facts,
          **plugin_unresolved }
      end

      # The principles that await their first full audit, in map order, which list-member-problems names in one
      # line.
      #: () -> Array[String]
      def awaiting_first_audit = @maps.select(&:awaits_first_audit?).map(&:principle_id)

      # Whether any map's member changed since an audit or acknowledgement assessed it, not only since it was
      # mapped, which --short exits 3 for rather than 4.
      #: () -> bool
      def assessed_change? = @maps.any?(&:assessed_change?)

      # For each map with a changed member an audit or acknowledgement assessed, how many, which --session-start
      # counts instead of listing each.
      #: () -> Hash[String, Integer]
      def assessed_changes = @maps.to_h { [it.principle_id, it.assessed_changes] }.reject { |_, count| count.zero? }

      # For each map with members no audit has assessed, how many, which --short counts on stdout.
      #: () -> Hash[String, Integer]
      def never_assessed = @maps.to_h { [it.principle_id, it.never_assessed] }.reject { |_, count| count.zero? }

      # The one-member audits list-member-problems offers, but for the principles in except, whose records wait on an
      # upgrade.
      #: (?except: Array[String]) -> AcknowledgementsToOffer
      def acknowledgements(except: []) = AcknowledgementsToOffer.new(@maps, except:)

      # For each map with members no baseline holds, its map file and the files those members are in, and in git
      # only those of them that differ from HEAD or are untracked, since committing an unchanged file does nothing.
      # In git the list is empty when every one is committed already.
      #: (MappedPrinciples) -> Hash[String, Array[String]]
      def files_to_commit(principles)
        no_baseline_paths.to_h do |id, paths|
          files = [principles.file(id), *paths]
          [id, @history&.inside_git? ? @history.uncommitted(files) : files]
        end
      end

      # In git, for each map whose map or member files differ from HEAD, those files, which an audit of it refuses
      # until they are committed; empty outside git, where an audit judges files as they are.
      #: (MappedPrinciples) -> Hash[String, Array[String]]
      def audit_files_to_commit(principles)
        return {} unless @history&.inside_git?

        @maps.filter_map do |map|
          files = @history.uncommitted(principles.audited_files(map.principle_id, map.members))
          [map.principle_id, files] unless files.empty?
        end.to_h
      end

      private

      # Each map's files holding a member with no baseline, by map id; a map with none is left out.
      #: () -> Hash[String, Array[String]]
      def no_baseline_paths
        @maps.to_h { |map| [map.principle_id, map.no_baseline_paths] }.reject { |_, paths| paths.empty? }
      end

      #: () ?{ (String, Member, String, String, PrincipleMappingHistory?) -> Hash[String, untyped] }
      #| -> Array[Hash[String, untyped]]
      def changed(&history)
        @maps.flat_map do |map|
          next map.changed unless history

          map.changed do |member, baseline, now, mapping|
            history.call(map.principle_id, member, baseline, now, mapping)
          end
        end
      end

      # Each map's count of members by the baseline they were compared with; a map with none is left out.
      #: () -> Hash[String, Hash[String, Integer]]
      def compared_with
        @maps.to_h { |map| [map.principle_id, map.compared_with] }.reject { |_, counts| counts.empty? }
      end

      # Why each map's members with no baseline have none, under no_baseline_because, or nothing when all have one.
      #: () -> Hash[String, Hash[String, String]]
      def no_baseline_because
        because = @maps.to_h { |map| [map.principle_id, map.no_baseline_because] }.compact
        because.empty? ? {} : { "no_baseline_because" => because }
      end

      # awaiting_first_audit under its own key, or nothing when no principle awaits one.
      #: () -> Hash[String, Array[String]]
      def awaiting_first_audit_field
        awaiting = awaiting_first_audit
        awaiting.empty? ? {} : { "awaiting_first_audit" => awaiting }
      end

      # Completion and empty-map facts, distinct from whether members have a baseline ready for a first audit.
      #: () -> Hash[String, Array[String]]
      def mapping_facts
        { "no_completed_audit" => @maps.select(&:no_completed_audit?).map(&:principle_id),
          "empty_maps" => @maps.select(&:empty_map?).map(&:principle_id) }.reject { |_key, ids| ids.empty? }
      end

      # Each plugin member no installed plugin gives, with why, which refuses nothing; none when every one resolves.
      #: () -> Hash[String, Array[Hash[String, untyped]]]
      def plugin_unresolved
        unresolved = @maps.flat_map(&:entries).select { it.fetch("state") == "plugin_unresolved" }
        unresolved.empty? ? {} : { "plugin_unresolved" => unresolved.map { it.slice("principle", "id", "reason") } }
      end

      #: (Array[Hash[String, untyped]]) -> bot
      def refuse(broken)
        named = broken.map { |each| [each["principle"], each["id"]].compact.join(" ") }
        missing = MissingFiles.new(broken, history: @history)
        raise missing.refusal("#{broken.length} members cannot be found or read: #{named.join(", ")}",
                              rerun: "#{Error::EXECUTABLE} list-member-problems",
                              note: "A map listed as unreadable_map needs its own refusal's repair. ")
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "locate_refusal"
require_relative "mapped_baseline"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One member as list-member-problems lists it: its principle, id and state against what this tool last knew of
    # its text, with what a changed member was compared with, or, when it cannot be found, its refusal.
    class MemberEntry
      # now is the member's hash now, or the refusal that says why it cannot be found. source is where a plugin
      # member found now comes from, at the version installed now.
      #: (String, Member, untyped, MemberProblems::Baselines, ?source: Hash[String, untyped]?) -> void
      def initialize(principle_id, member, now, baselines, source: nil)
        @principle_id = principle_id
        @member = member
        @now = now #: untyped
        @baselines = baselines
        @source = source
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h
        listed = { "principle" => @principle_id, "id" => @member.id }
        now = @now
        return compared(listed, now.to_s).merge(@source ? { "source" => @source } : {}) unless now.is_a?(Hash)
        # A plugin member found in no installed plugin, for any reason, is one quiet state, not broken, so a teammate
        # without the plugin, or with it in a shape this tool does not read, keeps every other member and map.
        return listed.merge("state" => "plugin_unresolved", "reason" => now.fetch("code")) if @member.plugin_reference

        listed.merge("state" => LocateRefusal.new(now).member_state).merge(now.except("status"))
      end

      private

      # listed, compared with the last audit's hash for the member, or else with its hash at the commit that mapped
      # it. An unchanged member compared only with the commit that mapped it has never been assessed, so it is
      # counted apart from one an audit assessed: counts is read first, and "unchanged" alone reads as audited.
      #: (Hash[String, untyped], String) -> Hash[String, untyped]
      def compared(listed, sha)
        then_sha, since = @baselines.of(@member.key)
        return listed.merge("state" => "no_baseline") unless since
        unless then_sha == sha
          return listed.merge("state" => "changed", "since" => since,
                              **(@baselines.waiting? ? { "waiting_on_an_upgrade" => true } : {}))
        end

        assessed = !MappedBaseline::KINDS.include?(since["baseline"])
        listed.merge("state" => assessed ? "unchanged" : "unchanged_since_mapping")
      end
    end
  end
end

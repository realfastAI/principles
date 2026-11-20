# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member_loads"
require_relative "loading_decision"
require_relative "accepted_loading"
require_relative "activation"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The members a full audit lists for the agent to weigh against the principle's activation, each with the
    # facts that put it there. It lists by fact and compares no globs, so
    # whether a member loads outside the activation is the agent's judgement.
    class LoadsToCheck
      # activation is the map's, or nil when none is declared; loads is each member's MemberLoads by id; accepted
      # is, by id, the decision the last completed audit accepted on a member's loading; hashes is each member's
      # text hash now, by id.
      #: (activation: Hash[String, untyped]?, loads: Hash[String, MemberLoads],
      #|  ?accepted: Hash[String, AcceptedLoading], ?hashes: Hash[String, String]) -> void
      def initialize(activation:, loads:, accepted: {}, hashes: {})
        @activation = activation
        @loads = loads
        @accepted = accepted
        @hashes = hashes
        freeze
      end

      # The activation, each listed member with what put it there and its loads, and the members this tool knows no
      # carrier for; nil when the activation lists nothing to check.
      #: () -> Hash[String, untyped]?
      def listed
        activation = @activation
        return unless activation && Activation.new(activation).full_audit_lists == "session_start_members"

        { "activation" => activation, "rows" => rows,
          "not_listed_no_known_carrier" => @loads.select { |_, loads| loads.moments == ["no_known_carrier"] }.keys }
      end

      # Each listed member's accepted decision, by id, as the record keeps it: its reason and the loads it accepted;
      # refused unless each listed member is decided exactly once, each accepted with a one-line reason.
      #: (untyped) -> Hash[String, Hash[String, untyped]]
      def decided(decisions)
        given = loading_decisions(decisions)
        expected = listed_by_id
        raise incomplete(expected.keys) unless given.map(&:member_id).sort == expected.keys.sort

        given.to_h { |decision| [decision.member_id, decision.kept(expected.fetch(decision.member_id))] }
      end

      private

      # Each of the answer's loading decisions, none when it gives no list.
      #: (untyped) -> Array[LoadingDecision]
      def loading_decisions(decisions)
        given = decisions.is_a?(Array) ? decisions : []
        given.each_with_index.map { |decision, index| LoadingDecision.new(decision, index) }
      end

      # Each listed member's row, by its id; none when the activation lists nothing to check.
      #: () -> Hash[String, Hash[String, untyped]]
      def listed_by_id = (listed&.fetch("rows") || []).to_h { |row| [row.fetch("member_id"), row] }

      #: (Array[String]) -> Error
      def incomplete(expected)
        Error.new("incomplete_loading_decisions",
                  "Decide each member listed in loads_to_check_against_activation exactly once: " \
                  "#{expected.empty? ? "none is listed" : expected.join(", ")}",
                  "Give loading_decisions one {member_id, decision} for each listed member, and none for another.")
      end

      #: () -> Array[Hash[String, untyped]]
      def rows
        @loads.filter_map do |id, loads|
          listed_for = loads.moments & ["session_start"]
          next if listed_for.empty?

          { "member_id" => id, "listed_for" => listed_for, "loads" => loads.to_h }.merge(last_accepted(id, loads.to_h))
        end
      end

      # What the last audit accepted on the member's loading, and whether what it weighed changed since; nothing
      # when no audit accepted it.
      #: (String, Hash[String, untyped]) -> Hash[String, untyped]
      def last_accepted(id, now)
        accepted = @accepted[id] or return {}
        { "last_accepted" => accepted.last_accepted(now, @hashes[id]) }
      end
    end
  end
end

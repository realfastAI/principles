# typed: strict
# frozen_string_literal: true

require_relative "member_loads"
require_relative "loading_scope"

module Principles
  module Models
    # One map's per-member loading scopes and the scope an added member newly represents.
    class MemberLoadingScopes
      #: (Hash[String, MemberLoads]) -> void
      def initialize(loads)
        @scopes = loads.transform_values { |member| LoadingScope.new(member.claude_code) }
                       .freeze #: Hash[String, LoadingScope]
        freeze
      end

      # A new known scope absent from prior known ones, beside at least one differing known scope.
      #: (String) -> Hash[String, untyped]
      def introduced_by(id)
        added = @scopes.fetch(id)
        prior = @scopes.except(id)
        known = prior.select { |_member_id, scope| scope.known? }
        return {} unless added.known? && known.any? && known.values.none? { |scope| scope == added }

        unknown = unclassified(prior)
        { "loading_basis" => MemberLoads::BASIS.dup, "scope" => added.to_h, "already_mapped" => grouped(known),
          **(unknown.empty? ? {} : { "not_compared" => unknown }) }
      end

      private

      #: (Hash[String, LoadingScope]) -> Array[Hash[String, untyped]]
      def grouped(known)
        groups = known.group_by { |_id, scope| scope }.map do |scope, members|
          { "member_ids" => members.map(&:first).sort, "scope" => scope.to_h }
        end
        groups.sort_by { |group| group.fetch("member_ids").first }
      end

      #: (Hash[String, LoadingScope]) -> Array[Hash[String, untyped]]
      def unclassified(prior)
        prior.reject { |_id, scope| scope.known? }.sort_by(&:first).map do |id, scope|
          { "member_id" => id, "scope" => scope.to_h }
        end
      end
    end
  end
end

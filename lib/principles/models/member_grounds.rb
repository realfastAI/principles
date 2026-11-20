# typed: strict
# frozen_string_literal: true

require_relative "json_digest"
require_relative "loading_facts"
require_relative "principle_members"
require_relative "member_loads"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The facts beside each member's own text that its assessment was judged on: its map entry, which holds its path,
    # locator, role and check, and when it loads, without the sizes an edit elsewhere in its file moves. A full audit
    # keeps a digest of each with the assessment, and carries the assessment forward only while both match.
    class MemberGrounds
      # members are the map's members; loads is each member's MemberLoads by id.
      #: (PrincipleMembers, Hash[String, MemberLoads]) -> void
      def initialize(members, loads)
        @members = members.by_id #: Hash[String, Member]
        @loads = loads
        freeze
      end

      # The digests of the member id's map entry and of its loading facts, as its kept assessment holds them.
      #: (String) -> Hash[String, String]
      def of(id)
        { "entry_sha256" => JsonDigest.new(@members.fetch(id).to_h).to_s,
          "loads_sha256" => JsonDigest.new(LoadingFacts.new(@loads.fetch(id).to_h).to_h).to_s }
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "member_problems"
require_relative "member_state"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Every principle of the project but one, each as list-member-problems reports its members, which an audit of
    # that one names when their members need an audit of their own: a completed audit for those its fixes changed,
    # and the meta-principle's full audit for those no audit has judged as they are now.
    class OtherPrinciples
      # Each principle of project but the one id names, its members as MemberProblems gives them; a map this tool
      # cannot read is among them, as list-member-problems lists it.
      #: (Project, but: String) -> OtherPrinciples
      def self.of(project, but:)
        new((project.principles.ids - [but]).to_h { [it, MemberProblems.for(project, it, listing_all: true)] })
      end

      # problems maps each principle's id to its members' problems.
      #: (Hash[String, MemberProblems]) -> void
      def initialize(problems)
        @problems = problems.freeze #: Hash[String, MemberProblems]
        freeze
      end

      # Each principle with a member in paths whose own text changed or whose reference broke, by id, with those
      # members; a principle with none is left out.
      #: (Array[String]) -> Hash[String, Array[MemberState]]
      def changed_or_broken_in(paths) = listed { it.changed_or_broken_in(paths) }

      # Each principle with members no audit has judged as they are now, by id, with those members by id and state;
      # a principle with none is left out.
      #: () -> Hash[String, Array[Hash[String, untyped]]]
      def unjudged = listed(&:unjudged)

      private

      # What the block gives for each principle's problems, by id, where it gives any.
      #: [T] () { (MemberProblems) -> Array[T] } -> Hash[String, Array[T]]
      def listed(&)
        @problems.transform_values(&).reject { |_, members| members.empty? }
      end
    end
  end
end

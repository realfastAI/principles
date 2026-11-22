# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../prose_list"
require_relative "principle"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # How a principle's map differs from the one an audit's request was printed from: each field of the map, and of
    # each member both maps hold, as it was and is now, which a stale request's refusal names.
    class MapChange
      #: (Principle, Principle) -> void
      def initialize(base, current)
        @base = base
        @current = current
        freeze
      end

      # Each change as a clause, such as: CLAUDE.md#Names's role was "a" and is now "b".
      #: () -> String
      def to_s = ProseList.new(clauses).to_s

      # Whether it names no change, as when only the members' order, or which members the map holds, changed.
      #: () -> bool
      def empty? = clauses.empty?

      # What an answer carried to a new request must judge again: each member whose entry changed, or, when a field of
      # the map itself changed, every member.
      #: () -> String
      def to_judge_again
        return "every member again against the map as it is now" unless map_fields.empty?

        changed = @current.members.select { |member| member_fields_of(member).any? }.map(&:id)
        entries = changed.one? ? "its map entry as it is" : "their map entries as they are"
        "#{ProseList.new(changed)} again against #{entries} now"
      end

      private

      #: () -> Array[String]
      def clauses = map_fields + member_fields

      #: () -> Array[String]
      def map_fields = differing("its", @base.to_h.except("members"), @current.to_h.except("members"))

      #: () -> Array[String]
      def member_fields = @current.members.flat_map { |member| member_fields_of(member) }

      # How member's entry differs from the one the base map holds under its key, none when it holds none.
      #: (Member) -> Array[String]
      def member_fields_of(member)
        was = @base.members.with_key(member.key)
        was ? differing("#{member.id}'s", was.to_h, member.to_h) : []
      end

      #: (String, Hash[String, untyped], Hash[String, untyped]) -> Array[String]
      def differing(whose, was, now)
        (was.keys | now.keys).reject { |field| was[field] == now[field] }.map do |field|
          "#{whose} #{field} was #{JSON.generate(was[field])} and is now #{JSON.generate(now[field])}"
        end
      end
    end
  end
end

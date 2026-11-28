# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A principle's plugin members no installed plugin gives, each with the refusal that says why, which no move or
    # removal in the project fixes, so they are refused apart from its broken members.
    class UnresolvedPluginMembers
      # members are their entries, each its id with its refusal's code, message and repair.
      #: (Array[Hash[String, untyped]], principle: String) -> void
      def initialize(members, principle:)
        @members = members
        @principle = principle
        freeze
      end

      #: () -> bool
      def empty? = @members.empty?

      # The refusal naming each member, with its own reason and repair.
      #: () -> Error
      def refusal
        ids = @members.map { |member| member.fetch("id") }
        Error.new("plugin_members_unresolved",
                  "#{ids.length} of #{@principle}'s members are in no plugin installed for this project: " \
                  "#{ids.join(", ")}",
                  "Follow each member's repair, then run the command again.")
             .including("principle" => @principle, "members" => @members)
      end
    end
  end
end

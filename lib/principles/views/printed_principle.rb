# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # A principle as printed: its id, map file, description and members. Each member is a plain hash that
    # already carries its "id", and on show-principle its snapshot and freshness too.
    class PrintedPrinciple
      #: String
      attr_reader :id
      #: String
      attr_reader :file
      #: String?
      attr_reader :description
      #: Array[Hash[String, untyped]]
      attr_reader :members
      #: Hash[String, untyped]?
      attr_reader :activation

      # activation is when the agent said the principle's work is in hand, or nil when it has not said.
      #: (id: String, file: String, description: String?, members: Array[Hash[String, untyped]],
      #|  ?activation: Hash[String, untyped]?) -> void
      def initialize(id:, file:, description:, members:, activation: nil)
        @id = id
        @file = file
        @description = description
        @members = members.freeze #: Array[Hash[String, untyped]]
        @activation = activation #: Hash[String, untyped]?
        freeze
      end

      # What the principle declares as a whole: its description, and its activation once the agent has said it.
      #: () -> Hash[String, untyped]
      def declared
        { "description" => @description, **({ "activation" => @activation } if @activation) }
      end

      #: () -> Hash[String, untyped]
      def map
        { **declared, "members" => @members }
      end
    end
  end
end

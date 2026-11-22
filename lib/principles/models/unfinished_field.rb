# typed: strict
# frozen_string_literal: true

require_relative "answer_place"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A field the agent left unfinished: empty, the template's placeholder, the answer guide's sample, or
    # an action not one of the four. It says where it sits in the answer and what to write there, which one
    # refusal lists beside every other.
    class UnfinishedField
      #: String
      attr_reader :repair

      #: (AnswerPlace, String, problem: String, repair: String) -> void
      def initialize(place, name, problem:, repair:)
        @place = place
        @name = name
        @problem = problem
        @repair = repair
        freeze
      end

      # Whose field it is, such as "Finding F1 reason".
      #: () -> String
      def to_s = "#{@place.subject} #{@name}"

      # Its entry in the refusal's fields, as a malformed answer's are.
      #: () -> Hash[String, String]
      def field = { "pointer" => @place.pointer, "problem" => @problem }
    end
  end
end

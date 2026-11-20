# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "member_file"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A place in an agent's answer: its JSON pointer, and whose part of the answer it is, such as "Finding F1".
    # A refusal about what sits there names both, so the agent can find the one pointer to repair.
    class AnswerPlace
      # What a pointer in an answer may do instead of quoting exactly a passage its file does not hold.
      ELSEWHERE = " Or point it at text the file holds."

      #: String
      attr_reader :pointer

      # Whose part of the answer it is, such as "Finding F1".
      #: String
      attr_reader :subject

      # The place of the member assessment at index in an answer, which names the member it assesses.
      #: (Integer, untyped) -> AnswerPlace
      def self.member_assessment(index, member_id) = new("/member_assessments/#{index}", "Member #{member_id}")

      #: (String, String) -> void
      def initialize(pointer, subject)
        @pointer = pointer
        @subject = subject
        freeze
      end

      # The place of name, a key or an index, inside this one, with the same subject.
      #: (String | Integer) -> AnswerPlace
      def child(name) = AnswerPlace.new("#{@pointer}/#{name}", @subject)

      # error, a refusal about what sits here, saying whose it is and where, as a malformed answer's fields do.
      #: (Error) -> Error
      def refusal(error)
        payload = error.payload
        message = payload.fetch("message")
        Error.new(payload.fetch("code"), "#{@subject}: #{message}", repair(payload))
             .including(payload.except("message", "repair"))
             .including("fields" => [{ "pointer" => @pointer, "problem" => message }])
      end

      private

      #: (Hash[String, untyped]) -> String
      def repair(payload)
        repair = payload.fetch("repair")
        MemberFile::QUOTE_NOT_FOUND.include?(payload.fetch("code")) ? repair + ELSEWHERE : repair
      end
    end
  end
end

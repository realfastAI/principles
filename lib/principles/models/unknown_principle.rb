# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "meta_principle"

module Principles
  module Models
    # An absent principle id, whose repair creates an ordinary map or sets up the keeping principle.
    class UnknownPrinciple
      #: (String) -> void
      def initialize(id)
        @id = id.dup.freeze #: String
        freeze
      end

      #: () -> Error
      def refusal
        creating = if @id == MetaPrinciple::ID
                     MetaPrinciple::SET_UP
                   else
                     "To create it: #{Error::EXECUTABLE} create-principle #{@id} --description TEXT"
                   end
        Error.new("unknown_principle", "No map named #{@id}",
                  "#{creating}\nTo see the mapped ids: #{Error::EXECUTABLE} list-principles")
      end
    end
  end
end

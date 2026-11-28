# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # How many of the newest captured sessions remove-logged-requests keeps, as --keep-sessions gives it: a whole
    # number, 0 keeping none, or 5 when it is not given.
    class KeptSessions
      DEFAULT = 5

      #: Integer
      attr_reader :count

      #: (String?) -> void
      def initialize(given)
        @count = given ? whole(given) : DEFAULT #: Integer
        freeze
      end

      private

      #: (String) -> Integer
      def whole(given)
        return given.to_i if given.match?(/\A\d+\z/)

        raise Error.new("invalid_keep_sessions", "--keep-sessions takes a whole number, not #{given.inspect}",
                        "Give how many of the newest sessions to keep, such as --keep-sessions 5; 0 keeps none.")
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # A principle id as a file name under .principles: lower-kebab-case, so it names one file in its directory
    # and never a path outside it. Every map and audit file is reached through one, whichever command asked.
    class PrincipleId
      FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ #: Regexp

      #: (String) -> void
      def initialize(id)
        unless id.match?(FORMAT)
          raise Error.new("invalid_id", "#{id.inspect} is not a principle id, which is lower-kebab-case",
                          "To see the mapped ids: #{Error::EXECUTABLE} list-principles")
        end

        @id = id
        freeze
      end

      # The file this id names in directory.
      #: (String) -> String
      def file_in(directory)
        File.join(directory, "#{@id}.json")
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A current audit entry protects its map from unconfirmed removal, whether the entry is readable or not.
    class AuditEntryProtectingMap
      #: (String, String) -> void
      def initialize(id, path)
        @id = id.dup.freeze #: String
        @path = path.dup.freeze #: String
        freeze
      end

      #: () -> Error
      def refusal
        Error.new("principle_has_audit_record", "#{@id} has a current audit entry",
                  "Removing this map deactivates it in routine reports; retained findings remain unresolved. " \
                  "Keep it unless that is intended.\n" \
                  "To inspect a readable record: #{Error::EXECUTABLE} show-audit #{@id}\n" \
                  "To deactivate only the map, retaining its audit entry: " \
                  "#{Error::EXECUTABLE} remove-principle #{@id} --confirm", @path)
      end
    end
  end
end

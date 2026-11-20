# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Every path git tracks, as git spells it, which tells a path renamed in case alone from the old spelling a disk
    # that folds case, such as macOS's default, still opens. Outside git it holds none, and refuses nothing.
    class TrackedPaths
      #: (Array[String]) -> void
      def initialize(paths)
        @paths = paths.to_set #: Set[String]
        freeze
      end

      # The spelling git tracks path under when it tracks it only in another case; nil when git tracks path as spelt,
      # or no spelling of it at all.
      #: (String) -> String?
      def other_case_of(path)
        @paths.find { it.casecmp?(path) } unless @paths.include?(path)
      end

      # path, refused while git tracks it only in another case: this disk opens it, but a clone on a disk that does
      # not fold case would not find it.
      #: (String) -> String
      def spelt_as_tracked(path)
        tracked = other_case_of(path) or return path

        raise Error.new("renamed_in_case", "git tracks #{path} only as #{tracked}, renamed in case alone: this disk " \
                                           "still opens the old name, but a clone on a case-sensitive disk would not",
                        "Check that #{tracked} is the file this member was mapped in, then move the member to " \
                        "that path with move-member.", path).including("tracked_as" => tracked)
      end
    end
  end
end

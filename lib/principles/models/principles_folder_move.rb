# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../data/principles_subfolder"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Whether a project's maps and records have moved from .memeplex, the folder's earlier name, to .principles.
    # Reading the new folder alone would show an unmoved project as unmapped, so every command that reads either
    # refuses until the folder moves, or until one of two folders holding them is removed. A file an older version
    # left in .memeplex beside no maps or records does not count.
    class PrinciplesFolderMove
      FOLDER = Data::PrinciplesSubfolder::FOLDER #: String
      EARLIER = Data::PrinciplesSubfolder::EARLIER_FOLDER #: String

      # held names the folders that hold maps/ or audits/.
      #: (Array[String]) -> void
      def initialize(held)
        @held = held
        freeze
      end

      # Refuses while the earlier folder holds maps or records.
      #: () -> void
      def refuse_while_pending
        return unless @held.include?(EARLIER)

        raise both_folders if @held.include?(FOLDER)

        raise not_moved
      end

      private

      #: () -> Error
      def both_folders
        Error.new("both_principles_folders",
                  "Both #{EARLIER} and #{FOLDER} hold maps or audit records; this version reads #{FOLDER} only",
                  "Removing either folder changes the user's project, so ask the user first. Compare the two " \
                  "before removing either: move into #{FOLDER} each map or record that only " \
                  "#{EARLIER} holds, and where both hold one, compare them and keep the current one; in git, " \
                  "git log shows which changed last. Then remove #{EARLIER} and commit.", EARLIER)
      end

      #: () -> Error
      def not_moved
        Error.new("principles_folder_not_moved",
                  "This project's maps or audit records are in #{EARLIER}, the folder's earlier name; this version " \
                  "reads #{FOLDER}",
                  "Moving the folder changes the user's project, so ask the user before moving it.\n" \
                  "To move it in git: git mv #{EARLIER} #{FOLDER}\nOutside git: mv #{EARLIER} #{FOLDER}\n" \
                  "Then commit the move. If anything untracked is left in #{EARLIER}, such as state.json and " \
                  "lock, which an older version wrote, ask the user before deleting it.", EARLIER)
      end
    end
  end
end

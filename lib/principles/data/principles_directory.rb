# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # A directory this project keeps Principles records in, refusing linked stores before any read or write.
    class PrinciplesDirectory
      FOLDER = ".principles"

      #: (String, ?String) -> void
      def initialize(root, name = "")
        @root = root
        @name = name
        freeze
      end

      #: () -> String
      def path
        [FOLDER, File.join(FOLDER, @name)].each { |relative| refuse_link(relative) }
        File.join(@root, FOLDER, @name)
      end

      private

      #: (String) -> void
      def refuse_link(relative)
        return unless File.symlink?(File.join(@root, relative))

        raise Error.new("symlinked_directory",
                        "#{relative} is a symbolic link, so a read or write there would leave the " \
                        "project",
                        "Replace the link with a real directory, then restore its files from version control.",
                        relative)
      end
    end
  end
end

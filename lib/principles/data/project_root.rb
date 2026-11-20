# typed: strict
# frozen_string_literal: true

require_relative "principles_subfolder"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The physical project boundary selected from an implicit working directory.
    class ProjectRoot
      #: (String) -> void
      def initialize(directory)
        @selected = File.realpath(directory) #: String
        freeze
      end

      #: () -> String
      def path
        directory = @selected
        loop do
          return directory if store?(directory)
          return @selected if entry?(directory, ".git") || File.dirname(directory) == directory

          directory = File.dirname(directory)
        end
      end

      private

      #: (String) -> bool
      def store?(directory)
        return true if entry?(directory, PrinciplesSubfolder::FOLDER)

        %w[maps audits].any? do |name|
          PrinciplesSubfolder.new(directory, name).held_in.include?(PrinciplesSubfolder::EARLIER_FOLDER)
        end
      end

      #: (String, String) -> bool
      def entry?(directory, name)
        File.lstat(File.join(directory, name))
        true
      rescue Errno::ENOENT
        false
      end
    end
  end
end

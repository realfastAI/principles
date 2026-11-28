# typed: strict
# frozen_string_literal: true

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The fast standard tools PATH holds, such as jq and rg, which a bulk scan runs in place of Ruby: a tool is on
    # PATH when a folder on it holds an executable file of that name.
    class ToolsOnPath
      #: (String) -> void
      def initialize(path)
        @folders = path.split(File::PATH_SEPARATOR).reject(&:empty?) #: Array[String]
        freeze
      end

      #: (String) -> bool
      def include?(tool)
        @folders.any? do |folder|
          found = File.join(folder, tool)
          File.file?(found) && File.executable?(found)
        end
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "bounded_file"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The folder Claude Code installed a copy of a plugin in. This tool only reads it, and walks no symbolic link, so
    # every file it names is inside the folder as the disk holds it.
    class PluginFolder
      # The most entries a walk looks at, far above any plugin, so a vast folder cannot hang a run.
      ENTRIES = 10_000 #: Integer

      #: (String) -> void
      def initialize(path)
        @path = path
        freeze
      end

      # Whether relative names a regular file in the folder, neither it nor any folder on the way a symbolic link.
      #: (String) -> bool
      def file?(relative)
        *folders, name = relative.split("/")
        inside = @path
        folders.each do |folder|
          inside = File.join(inside, folder)
          return false unless File.lstat(inside).directory?
        end
        File.lstat(File.join(inside, name.to_s)).file?
      rescue SystemCallError
        false
      end

      # The text of the file at relative, which file? holds, refused when it is not UTF-8 or is larger than BoundedFile
      # reads; a refusal names it by relative alone, never by where the host installed it.
      #: (String) -> String
      def read(relative)
        BoundedFile.new(File.join(@path, relative), shown_as: relative, named: "#{relative} in the plugin").read_text
      end

      # Whether relative, or a folder on the way to it, or the plugin's folder itself, is a symbolic link, which this
      # tool never follows.
      #: (String) -> bool
      def linked?(relative)
        segments = relative.split("/")
        (0..segments.size).any? { |count| File.lstat(File.join([@path] + segments.first(count))).symlink? }
      rescue SystemCallError
        false
      end

      # Each regular file in the folder by its path inside it, sorted, from a walk of at most ENTRIES entries that
      # enters no symbolic link; none when the folder is gone.
      #: () -> Array[String]
      def files = walked.take(ENTRIES).select { |_, entry| entry.file? }.map(&:first).sort

      private

      # Every entry under the folder, by its path inside it, met one at a time, so taking the first few walks no
      # further.
      #: () -> Enumerator[[String, File::Stat]]
      def walked = Enumerator.new { |found| visit("", found) }

      #: (String, untyped) -> void
      def visit(inside, found)
        entries(inside).each do |relative, entry|
          found << [relative, entry]
          visit(relative, found) if entry.directory?
        end
      end

      # Each entry directly in the folder at inside, by its path inside the plugin, as lstat sees it; none when it
      # cannot be read.
      #: (String) -> Array[[String, File::Stat]]
      def entries(inside)
        Dir.children(File.join(@path, inside)).sort.map do |name|
          relative = inside.empty? ? name : "#{inside}/#{name}"
          [relative, File.lstat(File.join(@path, relative))]
        end
      rescue SystemCallError
        []
      end
    end
  end
end

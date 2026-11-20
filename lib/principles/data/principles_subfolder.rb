# typed: strict
# frozen_string_literal: true

require "fileutils"
require "tempfile"
require_relative "../error"
require_relative "principle_id"
require_relative "bounded_file"
require_relative "principles_directory"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # One of this tool's own directories, .principles/maps or .principles/audits, holding one JSON file per id
    # as bytes; MapFiles and AuditFiles keep the rules for what those bytes say. A cloned project may hold
    # a committed symbolic link at .principles or at the directory, which would send this tool's reads and
    # writes outside the project, so each use refuses one.
    class PrinciplesSubfolder
      # The folder a project keeps its maps and audit records in.
      FOLDER = PrinciplesDirectory::FOLDER
      # Its name before the rename to principles; a project an older version mapped still holds it.
      EARLIER_FOLDER = ".memeplex"

      #: (String, String) -> void
      def initialize(root, name)
        @root = root
        @name = name
        freeze
      end

      # The directory's path, once neither it nor FOLDER is a symbolic link.
      #: () -> String
      def path = PrinciplesDirectory.new(@root, @name).path

      # Which of FOLDER and EARLIER_FOLDER hold this subfolder, in that order, so a model can refuse a project
      # whose maps or records have not moved. A file an older version left beside no subfolder holds none.
      #: () -> Array[String]
      def held_in
        [FOLDER, EARLIER_FOLDER].select { |folder| directory?(File.join(@root, folder, @name)) }
      end

      # The file id names in this directory.
      #: (String) -> String
      def file(id)
        PrincipleId.new(id).file_in(path)
      end

      # The ids of the JSON files in this directory, sorted.
      #: () -> Array[String]
      def ids
        Dir.glob(File.join(path, "*.json")).map { |each| File.basename(each, ".json") }.sort
      end

      #: (String) -> bool
      def exist?(id)
        File.exist?(file(id))
      end

      # Unlike exist?, a dangling final link is still a current entry; permission failures are not absence.
      #: (String, shown_as: String) -> bool
      def entry?(id, shown_as:)
        File.lstat(file(id))
        true
      rescue Errno::ENOENT
        false
      rescue SystemCallError
        raise Error.new("store_entry_unreadable", "Cannot inspect #{shown_as}",
                        "Restore access to this entry and its parent directories, then run the command again.",
                        shown_as)
      end

      # Unlink only a regular final entry, rechecking the store parents before the unlink.
      #: (String, shown_as: String) -> void
      def remove(id, shown_as:)
        refuse_unlink_type(File.lstat(file(id)), shown_as)
        File.unlink(file(id))
      rescue SystemCallError
        raise Error.new("store_remove_failed", "Cannot remove #{shown_as}",
                        "Check that the map still exists and restore directory access, then run the command again.",
                        shown_as)
      end

      # The text of id's file, read within BoundedFile's limit and named as shown_as in a refusal.
      #: (String, shown_as: String) -> String
      def read(id, shown_as:)
        BoundedFile.new(file(id), shown_as: shown_as).read
      end

      # Writes text as id's file, whole or not at all: it is written beside the file, then renamed over it.
      #: (String, String) -> void
      def write(id, text)
        directory = path
        FileUtils.mkdir_p(directory)
        Tempfile.create([id, ".json"], directory) do |temporary|
          temporary.write(text)
          temporary.flush
          File.rename(temporary.path, file(id))
        end
      end

      private

      #: (File::Stat, String) -> void
      def refuse_unlink_type(stat, shown_as)
        if stat.symlink?
          raise Error.new("symlinked_store_file", "#{shown_as} is a symbolic link",
                          "Replace the final link with the intended regular map file before removing it.", shown_as)
        end
        return if stat.file?

        raise Error.new("not_a_file", "#{shown_as} is not a regular file",
                        "Restore the intended regular map file before removing it.", shown_as)
      end

      #: (String) -> bool
      def directory?(path)
        File.stat(path).directory?
      rescue Errno::ENOENT, Errno::ENOTDIR
        false
      end
    end
  end
end

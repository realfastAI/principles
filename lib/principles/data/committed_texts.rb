# typed: strict
# frozen_string_literal: true

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Each file's text at a full commit sha, read once and kept frozen, since text at a full sha never changes.
    # Every read goes through one `git cat-file --batch` started on the first, not a git process per file:
    # list-member-problems reads hundreds, and starting each costs more than reading it. git ends it when
    # this tool's end of the pipe closes, on exit or once nothing holds these texts. A name git's line-based batch
    # cannot take, one holding a line break, or one naming anything but a file, such as a folder, is read by itself
    # through `git show`, the reader given.
    class CommittedTexts
      # What git prints before an object it found: its id, type and size. A name it found none for, or more than one,
      # gets a line ending "missing" or "ambiguous" instead, and no object.
      HEADER = /\A\h+ (?<type>[a-z]+) (?<size>\d+)\n\z/ #: Regexp

      #: (String, ^(String) -> String?) -> void
      def initialize(directory, show)
        @directory = directory
        @show = show
        @texts = {} #: Hash[String, String?]
        @batch = nil #: IO?
      end

      # The text of name, a full sha, a colon and a path from the project ("<sha>:./<path>"), or nil when that commit
      # does not hold a file there or git cannot be asked.
      #: (String) -> String?
      def text(name)
        return @texts[name] if @texts.key?(name)

        @texts[name] = name.match?(/[\r\n]/) ? @show.call(name) : read(name)
      end

      private

      #: (String) -> String?
      def read(name)
        batch = @batch ||= start
        batch.write("#{name}\n")
        found = HEADER.match(batch.gets.to_s) or return nil
        text = batch.read(found[:size].to_i).to_s
        batch.read(1)
        found[:type] == "blob" ? text.force_encoding("UTF-8").freeze : @show.call(name)
      rescue SystemCallError, IOError
        nil
      end

      #: () -> IO
      def start
        IO.popen(["git", "-C", @directory, "cat-file", "--batch"], "r+", err: File::NULL).tap do |batch|
          batch.sync = true
          Process.detach(batch.pid)
        end
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # A file this tool reads whole, refused unless it is a regular file no larger than LIMIT. Without the check,
    # a special file such as /dev/zero, or a file of gigabytes, would hang a run or exhaust its memory.
    class BoundedFile
      # Far above any instruction file, map, audit record or answer, and far below what exhausts memory.
      LIMIT = 4 * 1024 * 1024 #: Integer

      # shown_as is the path a refusal gives; named is what its message calls the file, such as "The answer" for a
      # file the agent named and holds the path of.
      #: (String, ?shown_as: String, ?named: String) -> void
      def initialize(path, shown_as: path, named: shown_as)
        @path = path
        @shown_as = shown_as
        @named = named
        freeze
      end

      # The file's text, read once it is known to be a regular file within LIMIT.
      #: (?encoding: String) -> String
      def read(encoding: "UTF-8")
        raise Error.new("unreadable_file", "#{@named} does not exist", "Name a file that exists.", @shown_as) unless
          File.exist?(@path)
        unless File.file?(@path)
          raise Error.new("not_a_file", "#{@named} is not a regular file", "Name a regular file.", @shown_as)
        end

        refuse_larger(File.size(@path))

        File.read(@path, encoding: encoding)
      end

      # A bounded regular file whose text must also be valid UTF-8, as project members require.
      #: () -> String
      def read_text
        text = read
        unless text.valid_encoding?
          raise Error.new("invalid_encoding", "Cannot read UTF-8 text", "Choose a text member.", @shown_as)
        end

        text
      end

      # Refuses bytes of text, such as stdin's, that are more than this tool reads from one file.
      #: (Integer) -> void
      def refuse_larger(bytes)
        return if bytes <= LIMIT

        raise Error.new("file_too_large", "#{@named} holds #{bytes} bytes, more than the #{LIMIT} bytes " \
                                          "read at most",
                        "Name a smaller file, or map a smaller part of it.", @shown_as)
      end
    end
  end
end

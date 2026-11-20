# typed: strict
# frozen_string_literal: true

require "io/wait"
require_relative "bounded_file"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The JSON a host passes on stdin to the hook that runs a command, as report-at-session-start and
    # report-after-commit read it. A host writes it and closes stdin, but an agent's shell can run the command with
    # stdin left open and sending nothing, which a plain read waits on for as long as the shell lets it.
    class HookInput
      # How long, in seconds, to wait for each part of the input before reading it as ended.
      WAIT = 1.0 #: Float

      #: (IO | StringIO, ?wait: Float) -> void
      def initialize(io, wait: WAIT)
        @io = io
        @wait = wait
        freeze
      end

      # The text on stdin, or nothing when stdin is a terminal, so a person trying the command by hand is not left
      # waiting on it, or cannot be read, since a hook's command exits 0. A pipe is read until it ends, or until
      # nothing more arrives within the wait.
      #: () -> String
      def text
        return "" if @io.tty?
        return @io.read(BoundedFile::LIMIT).to_s unless @io.is_a?(IO)

        arrived(@io)
      rescue IOError, SystemCallError
        ""
      end

      private

      # What arrives on io, within LIMIT, until it ends or a wait passes with nothing more.
      #: (IO) -> String
      def arrived(io)
        read = +""
        while read.bytesize < BoundedFile::LIMIT && io.wait_readable(@wait)
          part = next_part(io, BoundedFile::LIMIT - read.bytesize) or break
          read << part
        end
        read
      end

      # Up to length bytes that have arrived on io, or nil once it has ended.
      #: (IO, Integer) -> String?
      def next_part(io, length)
        io.readpartial(length)
      rescue EOFError
        nil
      end
    end
  end
end

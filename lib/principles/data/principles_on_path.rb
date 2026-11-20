# typed: strict
# frozen_string_literal: true

require "English"
require "timeout"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The principles a bare principles command runs, the first on PATH, when it is another file than this run's own:
    # its path, what it prints for --version and which of the commands asked about it does not run, or nil when PATH
    # finds none, finds this one, or that one prints no version.
    class PrinciplesOnPath
      # How long that copy may take to print its version before it is stopped and read as printing none.
      TIMEOUT_S = 3

      #: (String, own: String) -> void
      def initialize(path, own:)
        @folders = path.split(File::PATH_SEPARATOR) #: Array[String]
        @own = own
        freeze
      end

      # asking names the commands to ask that copy about, each started for its --help, so none for a caller that
      # needs only its version.
      #: (?Array[String]) -> [String, String, Array[String]]?
      def other(asking = [])
        found = first or return nil
        return nil if same_file?(found, @own)

        version = version_of(found).to_s.strip
        version.empty? ? nil : [found, version, asking.reject { runs?(found, it) }]
      rescue SystemCallError
        nil
      end

      # Whether the first principles on PATH is this run's own file, so a bare principles runs this same copy.
      #: () -> bool
      def own_first?
        found = first
        found ? same_file?(found, @own) : false
      end

      private

      # What found prints for --version when it exits 0 within TIMEOUT_S, or nil.
      #: (String) -> String?
      def version_of(found)
        printed = within_timeout(found, "--version")
        printed if $CHILD_STATUS&.success?
      end

      # Whether found runs command, as its --help exits 0 within TIMEOUT_S; a command it does not know exits 2.
      #: (String, String) -> bool
      def runs?(found, command)
        !within_timeout(found, command, "--help").nil? && $CHILD_STATUS&.success? == true
      end

      # What found prints on stdout for arguments, read until it exits, or nil once TIMEOUT_S passes and it is stopped.
      #: (String, *String) -> String?
      def within_timeout(found, *arguments)
        IO.popen([found, *arguments], err: File::NULL) do |io|
          Timeout.timeout(TIMEOUT_S) { io.read }
        rescue Timeout::Error
          Process.kill("KILL", io.pid)
          nil
        end
      end

      #: () -> String?
      def first
        @folders.map { File.join(it, "principles") }.find { File.file?(it) && File.executable?(it) }
      end

      #: (String, String) -> bool
      def same_file?(one, other)
        File.realpath(one) == File.realpath(other)
      rescue SystemCallError
        false
      end
    end
  end
end

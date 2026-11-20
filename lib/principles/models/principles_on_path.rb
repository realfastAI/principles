# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Another principles earlier on PATH than the plugin's own, which a bare principles command runs in place of it:
    # its path, the version it prints and which of the commands it was asked about it does not run.
    class PrinciplesOnPath
      #: String
      attr_reader :path, :version
      #: Array[String]
      attr_reader :lacking

      #: (String, String, ?lacking: Array[String]) -> void
      def initialize(path, version, lacking: [])
        @path = path
        @version = version
        @lacking = lacking.freeze #: Array[String]
        freeze
      end

      # Whether it runs another version than running, compared as each prints --version, whole, so a build of the
      # same release from another commit counts as another.
      #: (String) -> bool
      def shadows?(running) = @version != running
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "locator"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Where a finding is written up, as its record's recorded_at keeps it: a path, with a heading or a starting_at
    # inside it, or a url outside the project, such as an issue's. It holds that place as the Locator the hash it was
    # read from gives, which keeps its keys, nulls and order, since the record's bytes and each digest over them
    # depend on it; two pointers are the same when those hashes hold the same keys and values, in any order.
    class WriteUpPointer
      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @locator = Locator.new(fields) #: Locator
        freeze
      end

      # The link to a write-up outside the project, which this tool never reads, or nil for one in a file here.
      #: () -> String?
      def url = @locator.to_h["url"]

      # The project file it points into, which an audit commits and its record cites, or nil at a url.
      #: () -> String?
      def file = url ? nil : path

      # The file the write-up is in, for a pointer with no url.
      #: () -> String
      def path = @locator.path

      # Whether it names a starting_at inside its file.
      #: () -> bool
      def starting_at? = !@locator.starting_at.nil?

      # The same heading or starting_at in the file at path, as a decision on open findings checks git's match for a
      # missing file.
      #: (String) -> WriteUpPointer
      def in_file(path) = WriteUpPointer.new(to_h.merge("path" => path))

      # The opening of its write-up in project's file as it stands now, as WriteUpOpening finds it, or nil when there
      # is none; refused when the pointer no longer resolves.
      #: (Project) -> Hash[String, untyped]?
      def opening_in(project) = project.member_file(path).write_up_opening(@locator)

      # The pointer as its record's file holds it.
      #: () -> Hash[String, untyped]
      def to_h = @locator.to_h

      #: (untyped) -> bool
      def ==(other) = other.is_a?(WriteUpPointer) && other.to_h.eql?(to_h)

      alias eql? ==

      #: () -> Integer
      def hash = to_h.hash
    end
  end
end

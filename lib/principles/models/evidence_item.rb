# typed: strict
# frozen_string_literal: true

require_relative "locator"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One item of the evidence a finding was raised with, as its record keeps it: a path, with a heading, passage or
    # query inside it, or none to name the whole file. It holds that place as the Locator its record's hash
    # gives, which keeps the hash's keys and order, since the record's bytes depend on it.
    class EvidenceItem
      # Where in the project the item points, as MemberFile reads it.
      #: Locator
      attr_reader :locator

      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @locator = Locator.new(fields) #: Locator
        freeze
      end

      # The file it points into.
      #: () -> String
      def path = @locator.path

      # Whether it names its whole file, with no heading, passage or query inside it.
      #: () -> bool
      def whole_file? = @locator.whole_file?

      # The lines it names in the project's file at commit, or nil when that commit lacks the file or its place there.
      #: (ProjectHistory, String) -> Array[String]?
      def lines_at(history, commit) = history.at(commit).lines(@locator)

      # The lines it names in the project's file now; refused when it no longer resolves.
      #: (Project) -> Array[String]
      def lines_now(project) = project.member_file(path).lines_of(@locator)

      # The item as printed, with facts about it beside its fields.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def with_facts(facts) = to_h.merge(facts)

      # The item as its record holds it.
      #: () -> Hash[String, untyped]
      def to_h = @locator.to_h
    end
  end
end

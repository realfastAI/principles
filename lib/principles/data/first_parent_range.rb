# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "git_command"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Captured head's first-parent span, bounded by a supplied base or an independently verified actual root.
    class FirstParentRange
      SHA = /\A\h{40}(?:\h{24})?\z/ #: Regexp

      #: (GitCommand, String?, String) -> void
      def initialize(git, base, head)
        @git = git #: GitCommand
        @base = base&.dup&.freeze #: String?
        @head = head.dup.freeze #: String
        @first_parents = nil #: Array[String]?
      end

      #: (Array[String]) -> Array[String]
      def touching(paths)
        [@head, *changes(paths), @base].compact.uniq.freeze
      end

      #: (Array[String]) -> Array[String]
      def changes(paths)
        chain = first_parents
        selected = read(["rev-list", "--first-parent", "--full-history", "--end-of-options", range, "--", *paths])
                   .lines.map(&:strip)
        raise unavailable unless selected.all? { |sha| SHA.match?(sha) && chain.include?(sha) }

        selected.each(&:freeze).freeze
      end

      #: () -> Array[String]
      def commits = [*first_parents, @base].compact.uniq.freeze

      private

      # No path filter or history simplification may rewrite the topology used to certify this range.
      #: () -> Array[String]
      def first_parents
        @first_parents ||= read_parents
      end

      #: () -> Array[String]
      def read_parents
        confirm_revisions
        rows = read(["rev-list", "--first-parent", "--parents", "--end-of-options", range, "--"])
               .lines.map(&:split)
        return [] if rows.empty? && @head == @base

        chain = certified_chain(rows)
        confirm_root(chain.last.to_s) unless @base
        chain.each(&:freeze).freeze
      end

      # Only full commit names enter either native revision expression; nil requests the actual-root proof.
      #: () -> void
      def confirm_revisions
        raise unavailable unless SHA.match?(@head)
        raise unavailable if @base && !SHA.match?(@base)
      end

      #: (Array[Array[String]]) -> Array[String]
      def certified_chain(rows)
        shas = rows.map(&:first).compact
        parents = rows.map { |row| row[1] }
        connected = shas.first == @head && parents == [*shas.drop(1), @base]
        raise unavailable unless connected && rows.flatten.all? { SHA.match?(it) }

        shas
      end

      # rev-list hides a shallow boundary's parents. The raw commit must independently be an actual root.
      #: (String) -> void
      def confirm_root(sha)
        header = root_header(sha)
        kind, tree = header.first.to_s.split(" ", 2)
        return if kind == "tree" && SHA.match?(tree.to_s) && header.none? { it.start_with?("parent ") }

        raise unavailable
      end

      #: (String) -> Array[String]
      def root_header(sha)
        read(["cat-file", "-p", sha]).b.split("\n\n", 2).first.to_s.lines.map(&:chomp)
      end

      #: () -> String
      def range = @base ? "#{@base}..#{@head}" : @head

      #: (Array[String]) -> String
      def read(arguments)
        output, status = @git.run_with_status(arguments)
        raise unavailable unless status&.zero?

        output
      end

      #: () -> Error
      def unavailable
        return incomplete_root unless @base

        Error.new("git_history_unavailable",
                  "The supplied base has no verified first-parent path to selected commit #{@head}",
                  "Restore complete Git history and access, including the request's base commit, or start a new " \
                  "audit from the current branch. No audit record was written.")
      end

      #: () -> Error
      def incomplete_root
        Error.new("git_history_unavailable",
                  "Selected commit #{@head} lacks a verified first-parent line to its actual root",
                  "Restore complete first-parent ancestry and access to its commit and tree objects, then retry. " \
                  "No audit record was written.")
      end
    end
  end
end

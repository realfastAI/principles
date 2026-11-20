# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "git_command"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The literal entries of one exact committed tree, read through its supplied Git command.
    class CommittedTree
      SHA = /\A\h{40}(?:\h{24})?\z/ #: Regexp
      ENTRY_TYPES = { "100644" => "blob", "100755" => "blob", "120000" => "blob", "040000" => "tree",
                      "160000" => "commit" }.freeze #: Hash[String, String]

      #: (GitCommand, String, Error) -> void
      def initialize(git, revision, refusal)
        @git = git
        @revision = revision.dup.freeze #: String
        @refusal = refusal
        freeze
      end

      #: (String) -> bool
      def entry?(path) = !tree_output(path).empty?

      #: (String) -> Hash[String, String]?
      def raw_entry(path)
        output = tree_output(path)
        return nil if output.empty?

        fields = raw_metadata(output, path)
        return fields.freeze unless fields.fetch("type") == "blob"

        fields.merge("bytes" => blob_bytes(fields.fetch("object_id"))).freeze
      end

      private

      #: (String) -> String
      def tree_output(path)
        raise @refusal unless SHA.match?(@revision)

        output, status = @git.run_with_status(["ls-tree", "-z", @revision, "--", path])
        raise @refusal unless status&.zero?

        output
      end

      #: (String, String) -> Hash[String, String]
      def raw_metadata(output, path)
        record = output.b
        raise @refusal unless record.end_with?("\0") && record.count("\0") == 1

        metadata, returned = record.delete_suffix("\0").split("\t", 2)
        raise @refusal unless returned == path.b

        entry_fields(metadata.to_s)
      end

      #: (String) -> Hash[String, String]
      def entry_fields(metadata)
        match = /\A([0-7]{6}) (blob|tree|commit) (\h{40}(?:\h{24})?)\z/.match(metadata)
        raise @refusal unless match

        parts = match.captures.map { it.to_s.freeze }
        mode = parts.fetch(0)
        type = parts.fetch(1)
        object_id = parts.fetch(2)
        raise @refusal unless ENTRY_TYPES[mode] == type && object_id.length == @revision.length

        { "mode" => mode, "type" => type, "object_id" => object_id }
      end

      #: (String) -> String
      def blob_bytes(object_id)
        bytes, status = @git.run_with_status(["cat-file", "blob", object_id])
        raise @refusal unless status&.zero?

        bytes.b.freeze
      end
    end
  end
end

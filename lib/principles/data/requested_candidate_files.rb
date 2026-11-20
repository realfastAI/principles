# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "candidate_files_found"

module Principles
  module Data
    # Only the literal files the agent asked to outline, with each unread or refused request retained.
    class RequestedCandidateFiles
      #: (ProjectFiles, Array[String]) -> void
      def initialize(files, paths)
        @files = files
        @paths = paths.map { |path| path.sub(%r{\A(?:\./)+}, "") }.uniq.sort #: Array[String]
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h
        results = @paths.map { |path| requested(path) }
        listing = { "files" => results.filter_map { |result| result["file"] },
                    "unreadable" => results.filter_map { |result| result["refusal"] },
                    "possibly_test_data" => [], "selected_files" => @paths }
        ignored = results.filter_map { |result| result["ignored"] }
        ignored.empty? ? listing : listing.merge("ignored" => ignored, "ignored_ancestor_folders" => [])
      end

      private

      # Resolve before asking git: an invalid request cannot stop the other paths' ignore checks.
      #: (String) -> Hash[String, untyped]
      def requested(path)
        @files.resolve(path)
        ignored = @files.ignored_paths(@files.text_paths(path))
        return { "ignored" => path } if ignored&.any?

        { "file" => CandidateFilesFound.listed(path, text: @files.read_text(path), leads_to: @files.leads_to(path)) }
      rescue Error => e
        { "refusal" => e.payload }
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "principles_directory"
require_relative "principles_subfolder"
require_relative "map_files"
require_relative "audit_files"
require_relative "guidance_search_paths_file"
require_relative "request_logging_folder"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The files this tool keeps for a project under .principles: its member maps, its audit records, its recorded
    # guidance search paths and its git-ignored logged requests, which a project is handed together.
    class PrinciplesStore
      # The store of the project at root.
      #: (String) -> PrinciplesStore
      def self.at(root)
        new(maps: MapFiles.new(PrinciplesSubfolder.new(root, "maps")),
            audits: AuditFiles.new(PrinciplesSubfolder.new(root, "audits")),
            guidance_search_paths: GuidanceSearchPathsFile.new(PrinciplesDirectory.new(root)),
            request_logging: RequestLoggingFolder.new(root))
      end

      #: MapFiles
      attr_reader :maps

      #: AuditFiles
      attr_reader :audits

      #: GuidanceSearchPathsFile
      attr_reader :guidance_search_paths

      #: RequestLoggingFolder
      attr_reader :request_logging

      #: (maps: MapFiles, audits: AuditFiles, guidance_search_paths: GuidanceSearchPathsFile,
      #|  request_logging: RequestLoggingFolder) -> void
      def initialize(maps:, audits:, guidance_search_paths:, request_logging:)
        @maps = maps
        @audits = audits
        @guidance_search_paths = guidance_search_paths
        @request_logging = request_logging
        freeze
      end
    end
  end
end

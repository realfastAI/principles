# typed: strict
# frozen_string_literal: true

require_relative "principles_directory"
require_relative "bounded_file"
require_relative "json_text"
require_relative "schema_check"
require "fileutils"
require "tempfile"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The project's one committed list of additional guidance globs.
    class GuidanceSearchPathsFile
      NAME = "guidance-search-paths.json"
      FILE = "#{PrinciplesDirectory::FOLDER}/#{NAME}".freeze #: String
      FORMAT = 1

      #: (PrinciplesDirectory) -> void
      def initialize(directory)
        @directory = directory
      end

      #: () -> Hash[String, untyped]
      def read
        text = optional_text
        text ? parse(text) : { "format" => FORMAT, "globs" => [] }
      rescue SystemCallError => e
        raise io_error("read", e)
      end

      #: (Hash[String, untyped]) -> void
      def write(fields)
        target = path
        FileUtils.mkdir_p(@directory.path)
        Tempfile.create(["guidance-search-paths", ".json"], @directory.path) do |temporary|
          temporary.write("#{JSON.pretty_generate(fields)}\n")
          temporary.flush
          File.rename(temporary.path, target)
        end
      rescue SystemCallError => e
        raise io_error("write", e)
      end

      #: () -> String
      def relative = FILE

      # Schema validation is shared with the in-memory adapter; filesystem reads remain here.
      #: (String) -> Hash[String, untyped]
      def parse(text)
        parsed = JsonText.new(text).parsed
        refuse_newer(parsed)
        problems = SchemaCheck.new("guidance-search-paths").problems(parsed)
        return parsed if problems.empty?

        raise Error.new("invalid_guidance_search_paths", "#{FILE} is not in the shape this tool writes",
                        "Repair the listed fields or restore the configuration from version control.", FILE,
                        fields: problems)
      rescue JSON::ParserError => e
        raise Error.new("unparseable_guidance_search_paths", e.message,
                        "Repair this JSON or restore the configuration from version control.", FILE)
      end

      private

      # Only a genuinely absent file is optional, never an unreadable store or a linked file.
      #: () -> String?
      def optional_text
        target = path
        unless File.lstat(target).file?
          raise Error.new("invalid_guidance_search_paths", "#{FILE} is not a regular configuration file",
                          "Replace it with a regular JSON configuration file, then retry.", FILE)
        end
        BoundedFile.new(target, shown_as: FILE).read
      rescue Errno::ENOENT
        nil
      end

      #: () -> String
      def path
        target = File.join(@directory.path, NAME)
        if File.symlink?(target)
          raise Error.new("symlinked_guidance_search_paths", "#{FILE} is a symbolic link",
                          "Replace the link with a regular committed configuration file.", FILE)
        end

        target
      end

      #: (untyped) -> void
      def refuse_newer(parsed)
        format = parsed.is_a?(Hash) ? parsed["format"] : nil
        return unless format.is_a?(Integer) && format > FORMAT

        raise Error.new("newer_guidance_search_paths", "#{FILE} uses format #{format}; this version reads #{FORMAT}",
                        "Update principles and leave the configuration unchanged; it is not broken.", FILE)
      end

      #: (String, SystemCallError) -> Error
      def io_error(action, error)
        Error.new("guidance_search_paths_io_error", "#{FILE}: cannot #{action}: #{error.class.new(nil).message}",
                  "Restore a readable project-local store and file, then retry; no configuration was accepted.", FILE)
      end
    end
  end
end

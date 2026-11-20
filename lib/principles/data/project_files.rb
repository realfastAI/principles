# typed: strict
# frozen_string_literal: true

require "json"
require "open3"
require_relative "../error"
require_relative "json_text"
require_relative "bounded_file"
require_relative "candidate_files_found"
require_relative "linked_path"
require_relative "requested_candidate_files"
module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # Reads the selected project's files: resolves paths inside it, reads members' text and lists candidates.
    class ProjectFiles
      #: String
      attr_reader :root

      #: (String) -> void
      def initialize(root)
        @root = File.realpath(root) #: String
      end

      # A project file's text, refused unless it is a readable UTF-8 file inside the project.
      # Models::MemberFile finds a member's place in it.
      #: (String) -> String
      def read_text(path)
        BoundedFile.new(resolve(path), shown_as: path).read_text
      rescue SystemCallError => e
        raise Error.new("unreadable_file", e.message, "Restore a readable project-local file, then retry.", path)
      end

      # The paths the text at path depends on, each symbolic link on the way and then the file they lead to, as
      # LinkedPath gives them; path alone when it passes through no link.
      #: (String) -> Array[String]
      def text_paths(path) = linked(path).text_paths

      # The file path's links lead to, read in place of path; path itself when it passes through no link.
      #: (String) -> String
      def leads_to(path) = linked(path).leads_to

      # path as the links on the disk lead it.
      #: (String) -> LinkedPath
      def linked(path)
        LinkedPath.new(path: path, root: @root, read_link: lambda { |relative|
          absolute = File.join(@root, relative)
          File.readlink(absolute) if File.symlink?(absolute)
        })
      end

      # Whether path names a file inside the project; its contents are not read.
      #: (String) -> bool
      def file?(path)
        absolute = File.expand_path(path, @root)
        absolute.start_with?("#{@root}/") && File.file?(absolute)
      end

      # Whether path names a folder inside the project.
      #: (String) -> bool
      def folder?(path)
        absolute = File.expand_path(path, @root)
        absolute.start_with?("#{@root}/") && File.directory?(absolute)
      end

      #: (String) -> String
      def resolve(path)
        absolute = File.expand_path(path, @root)
        check_inside(absolute, path)
        unless File.file?(absolute)
          raise Error.new("not_a_file", "Reference does not name a file", "Select a regular text file.",
                          path)
        end

        absolute
      rescue SystemCallError => e
        raise Error.new("unreadable_file", e.message, "Restore the referenced file or correct its path.", path)
      end

      # Refuses a path that leaves the project, directly or through a link.
      #: (String, String) -> void
      def check_inside(absolute, path)
        return if absolute.start_with?("#{@root}/") && File.realpath(absolute).start_with?("#{@root}/")

        raise Error.new("outside_project", "Reference is outside the selected project",
                        "Choose a file inside this project; external scopes are not supported in this alpha.", path)
      end

      # The instruction files hosts load by convention, as CandidateFilesFound lists them, and the files also names.
      #: (?also: Array[String], ?matching: Array[String]) -> Hash[String, untyped]
      def inventory(also: [], matching: []) = CandidateFilesFound.new(self, also:, matching:).to_h

      # Literal outline requests never walk the project or load saved search paths.
      #: (Array[String]) -> Hash[String, untyped]
      def requested_inventory(paths) = RequestedCandidateFiles.new(self, paths).to_h

      #: (Array[String]) -> Array[String]?
      def ignored_paths(paths) = IgnoredByGit.new(@root, paths).facts&.fetch("ignored")

      # JSON from the file at path, which a refusal's message calls named.
      #: (String, ?named: String) -> untyped
      def read_json(path, named: path)
        parse_json(BoundedFile.new(path, named:).read, path, named:)
      rescue SystemCallError => e
        # The system's reason alone, such as "Permission denied", without the path its message ends with.
        reason = e.class.new(nil).message
        raise Error.new("unreadable_file", "#{named} cannot be read: #{reason}", "Supply a readable JSON file.", path)
      end

      # JSON from text read elsewhere, such as stdin, given by source in a refusal, whose message calls it named.
      #: (String, String, ?named: String) -> untyped
      def parse_json(text, source, named: source)
        BoundedFile.new(source, named:).refuse_larger(text.bytesize)
        JsonText.new(text).parsed
      rescue JSON::ParserError => e
        raise Error.new("unparseable_json", e.message, "Repair this JSON and retry; no response was accepted.",
                        source)
      end
    end
  end
end

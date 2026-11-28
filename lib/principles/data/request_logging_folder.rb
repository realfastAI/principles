# typed: strict
# frozen_string_literal: true

require_relative "principles_directory"
require_relative "logged_request_scan"
require "fileutils"
require "json"
require "tempfile"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The folder where the host writes each request it sends, with the files this tool writes beside them: the
    # .gitignore that has git ignore the folder, and the launch file that switches the capture. Each name is
    # relative to the folder.
    class RequestLoggingFolder
      NAME = "request-logging"
      FOLDER = "#{PrinciplesDirectory::FOLDER}/#{NAME}".freeze #: String
      IGNORE = ".gitignore"
      SETTINGS = "settings.json"
      REQUESTS = "requests"
      # The host's one line per response it received, naming the request and response files and the session.
      INDEX = "#{REQUESTS}/index.jsonl".freeze #: String

      # A file the host wrote under requests/: its name there, its size and when it was last written.
      class CapturedFile
        #: String
        attr_reader :name
        #: Integer
        attr_reader :bytes
        #: Time
        attr_reader :modified_at

        #: (name: String, bytes: Integer, modified_at: Time) -> void
        def initialize(name:, bytes:, modified_at:)
          @name = name
          @bytes = bytes
          @modified_at = modified_at
          freeze
        end
      end

      # One line of the host's index: the session, when, and the paths of the request and response files it names.
      class IndexLine
        #: String
        attr_reader :session_id, :timestamp, :request_file, :response_file

        #: (Hash[String, String]) -> void
        def initialize(fields)
          @session_id = fields.fetch("session_id") #: String
          @timestamp = fields.fetch("timestamp") #: String
          @request_file = fields.fetch("request_file") #: String
          @response_file = fields.fetch("response_file") #: String
          freeze
        end
      end

      #: (String) -> void
      def initialize(root)
        @root = root
        @directory = PrinciplesDirectory.new(root, NAME) #: PrinciplesDirectory
        freeze
      end

      # name as a path relative to the project.
      #: (String) -> String
      def relative(name) = "#{FOLDER}/#{name}"

      # name as an absolute path, as a launch file must name the folder the host writes to.
      #: (String) -> String
      def absolute(name) = File.join(@root, FOLDER, name)

      #: () -> bool
      def exist? = File.directory?(@directory.path)

      # Every file in the folder, as a name relative to it, sorted.
      #: () -> Array[String]
      def files
        base = @directory.path
        Dir.glob("**/*", File::FNM_DOTMATCH, base: base).select { |name| File.file?(File.join(base, name)) }.sort
      end

      # Every file the host wrote under requests/, but its index, sorted by name.
      #: () -> Array[CapturedFile]
      def captured_files
        base = File.join(@directory.path, REQUESTS)
        (Dir.exist?(base) ? Dir.children(base).sort : []).filter_map do |name|
          path = File.join(base, name)
          next if name == File.basename(INDEX) || !File.file?(path)

          stat = File.stat(path)
          CapturedFile.new(name: name, bytes: stat.size, modified_at: stat.mtime.utc)
        end
      end

      # Each line of the host's index, leaving out a line that is not a JSON object naming a session and its files.
      #: () -> Array[IndexLine]
      def index_lines
        path = File.join(@directory.path, INDEX)
        File.file?(path) ? IndexLines.new(File.read(path)).lines : []
      end

      # Writes name, creating the folder readable only by its owner, since what it holds is a whole session's context.
      #: (String, String) -> void
      def write(name, text)
        target = File.join(@directory.path, name)
        FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
        Tempfile.create(["request-logging", ".tmp"], File.dirname(target)) do |temporary|
          temporary.write(text)
          temporary.flush
          File.rename(temporary.path, target)
        end
      end

      # Writes the launch file, its fields as JSON.
      #: (Hash[String, untyped]) -> void
      def write_settings(fields) = write(SETTINGS, "#{JSON.pretty_generate(fields)}\n")

      #: (String) -> void
      def remove(name) = File.delete(File.join(@directory.path, name))

      # Removes one file the host wrote directly under requests/, refusing any other name, an index line's included,
      # so a line naming a path elsewhere or the index itself cannot reach it.
      #: (String) -> void
      def remove_request(name)
        unless name.match?(%r{\A[^/]+\z}) && !%w[. ..].include?(name) && name != File.basename(INDEX)
          raise ArgumentError, "not a captured file under #{REQUESTS}/: #{name.inspect}"
        end

        remove("#{REQUESTS}/#{name}")
      end

      # The requests the host captured here, scanned by jq and rg.
      #: () -> LoggedRequestScan
      def scan = LoggedRequestScan.new(File.join(@directory.path, REQUESTS))

      # Removes the folder when nothing is left in it.
      #: () -> void
      def remove_if_empty
        Dir.rmdir(@directory.path) if exist? && Dir.empty?(@directory.path)
      end
    end

    # The host's index text read as lines, shared by the folder and its stand-in.
    class IndexLines
      FIELDS = %w[session_id timestamp request_file response_file].freeze #: Array[String]

      #: (String) -> void
      def initialize(text)
        @text = text
        freeze
      end

      #: () -> Array[RequestLoggingFolder::IndexLine]
      def lines
        @text.each_line.filter_map do |line|
          fields = JSON.parse(line)
          next unless fields.is_a?(Hash) && FIELDS.all? { |field| fields[field].is_a?(String) }

          RequestLoggingFolder::IndexLine.new(fields)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end

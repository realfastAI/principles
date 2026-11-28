# typed: strict
# frozen_string_literal: true

require_relative "../data/request_logging_folder"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # What the host captured under requests/, read from its files and its index: each session's requests, files and
    # bytes, and the request files no index line names, whose cause is the agent's to judge.
    class CapturedSessions
      # Files counted, and their bytes.
      class Tally
        #: Integer
        attr_reader :files, :bytes

        #: (files: Integer, bytes: Integer) -> void
        def initialize(files:, bytes:)
          @files = files
          @bytes = bytes
          freeze
        end

        #: () -> Hash[String, Integer]
        def to_h = { "files" => @files, "bytes" => @bytes }
      end

      # One session's tally: its requests, the files they and their responses fill, and those files' bytes.
      class Session
        #: String
        attr_reader :session_id
        #: Integer
        attr_reader :requests
        #: Tally
        attr_reader :tally

        #: (String, Integer, Tally) -> void
        def initialize(session_id, requests, tally)
          @session_id = session_id
          @requests = requests
          @tally = tally
          freeze
        end

        #: () -> Hash[String, untyped]
        def to_h = { "session_id" => @session_id, "requests" => @requests, **@tally.to_h }
      end

      #: (Array[Data::RequestLoggingFolder::CapturedFile], Array[Data::RequestLoggingFolder::IndexLine]) -> void
      def initialize(files, index_lines)
        @files = files.to_h { |file| [file.name, file] } #: Hash[String, Data::RequestLoggingFolder::CapturedFile]
        @index_lines = index_lines
        freeze
      end

      # Each session the index names, in the order it first names them.
      #: () -> Array[Session]
      def sessions
        @index_lines.group_by(&:session_id).map do |session_id, lines|
          named = lines.flat_map { |line| named_files(line) }.uniq
          Session.new(session_id, lines.size, Tally.new(files: named.size, bytes: named.sum(&:bytes)))
        end
      end

      # The request files no index line names, counted, and their bytes.
      #: () -> Tally
      def orphans
        unnamed = unnamed_requests
        Tally.new(files: unnamed.size, bytes: unnamed.sum(&:bytes))
      end

      # When the newest request file was written, which says whether requests still arrive, or nil before any.
      #: () -> Time?
      def newest_request_written_at
        @files.values.select { |file| file.name.end_with?(".request.json") }.map(&:modified_at).max
      end

      # Whether the host captured no request yet, as before a session is launched with capture on.
      #: () -> bool
      def none? = newest_request_written_at.nil?

      # The session of the index's newest line, by its timestamp, or nil before the index has one. It compares the
      # timestamps as text, which orders them only while the host writes them in one ISO 8601 form, not yet seen on a
      # real launch.
      #: () -> String?
      def newest_session_id = @index_lines.max_by(&:timestamp)&.session_id

      # The names of the files the index names for every session but the newest keep, ranked by each session's
      # newest line, as newest_session_id compares them, leaving every file a kept session also names; then the
      # request files no line names that were written before every kept session's file. With no session kept, every
      # such file stays, since it may belong to a session still running.
      #: (Integer) -> Array[String]
      def older_than_newest(keep)
        ranked = @index_lines.group_by(&:session_id).values.sort_by { |lines| lines.map(&:timestamp).max.to_s }
        kept = ranked.last(keep).flatten
        names(ranked.flatten - kept) - names(kept) + orphans_written_before(kept)
      end

      private

      #: (Array[Data::RequestLoggingFolder::IndexLine]) -> Array[String]
      def orphans_written_before(kept)
        oldest = kept.flat_map { |line| named_files(line) }.map(&:modified_at).min
        return [] unless oldest

        unnamed_requests.select { |file| file.modified_at < oldest }.map(&:name)
      end

      #: () -> Array[Data::RequestLoggingFolder::CapturedFile]
      def unnamed_requests
        indexed = @index_lines.map { |line| base_name(line.request_file) }
        @files.values.select { |file| file.name.end_with?(".request.json") && !indexed.include?(file.name) }
      end

      #: (Array[Data::RequestLoggingFolder::IndexLine]) -> Array[String]
      def names(lines) = lines.flat_map { |line| named_files(line) }.map(&:name).uniq

      #: (String) -> String
      def base_name(path) = path.split("/").last.to_s

      # The files a line names that the folder holds, by name, since the index names them by their full paths.
      #: (Data::RequestLoggingFolder::IndexLine) -> Array[Data::RequestLoggingFolder::CapturedFile]
      def named_files(line)
        [line.request_file, line.response_file].filter_map { |path| @files[base_name(path)] }
      end
    end
  end
end

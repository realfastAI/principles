# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../data/request_logging_folder"
require_relative "../data/project_files"
require_relative "captured_sessions"
require_relative "logged_request_scan_completeness"
require_relative "logged_request_reach"
require_relative "member_reach"
require_relative "kept_sessions"
require_relative "members_in_logged_requests"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The project's logged requests: each request the host sends, written into a folder git must ignore, since a
    # request holds the session's whole working context. Each command here checks first that git ignores the folder
    # and every file in it, and refuses otherwise; this is the one guard they share.
    class RequestLogging
      FOLDER = Data::RequestLoggingFolder
      IGNORE_EVERYTHING = "*\n"
      # The paths each command checks git ignores, beside every file already in the folder.
      GUARDED = [FOLDER::IGNORE, FOLDER::SETTINGS, "#{FOLDER::REQUESTS}/"].freeze #: Array[String]

      #: (Data::RequestLoggingFolder, Data::ProjectFiles) -> void
      def initialize(folder, files)
        @folder = folder
        @files = files
        freeze
      end

      # Writes the .gitignore that has git ignore the folder, and once git confirms it does, the launch file that
      # switches capture on, and gives the paths it wrote; when git does not ignore it, removes what it wrote and
      # refuses.
      #: () -> Array[String]
      def turn_on
        created = !@folder.exist?
        written = @folder.files.include?(FOLDER::IGNORE) ? [] : [FOLDER::IGNORE]
        written.each { |name| @folder.write(name, IGNORE_EVERYTHING) }
        refuse_unignored(written, created)
        @folder.write_settings("env" => capturing)
        [*written, FOLDER::SETTINGS].map { |name| @folder.relative(name) }
      end

      # The launch file, by its absolute path, as the host is started with it.
      #: () -> String
      def launch_file = @folder.absolute(FOLDER::SETTINGS)

      # Empties the launch file's env, so a launch with it captures nothing, and gives the paths it wrote: none where
      # request logging was never turned on. Every logged request stays.
      #: () -> Array[String]
      def turn_off
        refuse_while_unguarded
        return [] unless @folder.files.include?(FOLDER::SETTINGS)

        @folder.write_settings("env" => {})
        [@folder.relative(FOLDER::SETTINGS)]
      end

      # Whether no request is captured, so nothing shows which members reach the context: the folder is not there, or
      # holds no request yet. Refuses while the folder is unguarded.
      #: () -> bool
      def none_captured? = !@folder.exist? || captured.none?

      # Whether request logging is in use here: its folder is, turned on or holding requests kept from before.
      #: () -> bool
      def in_use? = @folder.exist?

      # What the host captured, once the guard passes.
      #: () -> CapturedSessions
      def captured
        refuse_while_unguarded
        CapturedSessions.new(@folder.captured_files, @folder.index_lines)
      end

      # Removes the host's files of every session but the newest keep_sessions, 5 unless given, and gives the paths it
      # removed. Refuses while the folder is unguarded, and a count that is not a whole number, before removing any.
      #: (keep_sessions: String?) -> Array[String]
      def remove(keep_sessions:)
        refuse_while_unguarded
        names = captured.older_than_newest(KeptSessions.new(keep_sessions).count)
        names.each { |name| @folder.remove_request(name) }
        names.map { |name| @folder.relative("#{Data::RequestLoggingFolder::REQUESTS}/#{name}") }
      end

      # Refuses while the folder exists unguarded: its .gitignore gone, or git not ignoring every path there. Every
      # read of the folder asks this first, since a logged request git does not ignore can be committed.
      #: () -> void
      def refuse_while_unguarded
        refusal = unguarded_refusal
        raise refusal if refusal
      end

      # The refusal every read of the folder gives while it exists unguarded, or nil while git ignores it or it is
      # not there; for a read that carries on without the logged requests, such as a full audit's request.
      #: () -> Error?
      def unguarded_refusal
        return unless @folder.exist?
        return unguarded unless @folder.files.include?(FOLDER::IGNORE)

        not_ignored unless ignored?
      end

      # Where each of members' text was seen in the captured requests, scanned by jq and rg, once the folder is
      # guarded.
      # Each request that is not whole JSON is named under unreadable, with its reason, since what it held is unknown,
      # and completeness says how many requests and strings the scan read, and whether it read every request through.
      #: (MembersInLoggedRequests)
      #|   -> { members_by_status: Hash[String, Integer], members: Array[Hash[String, untyped]], orphans: Integer,
      #|        quoting_requests: Array[String], unreadable: Array[Hash[String, String]],
      #|        completeness: Hash[String, untyped] }
      def members_seen(members) = scanned(members).first

      # The report members_seen gives, but each member's reach in place of its places, as MemberReach lists it, so
      # the report is bounded by the members mapped rather than growing with every request that holds them.
      #: (MembersInLoggedRequests)
      #|   -> { members_by_status: Hash[String, Integer], members: Array[Hash[String, untyped]], orphans: Integer,
      #|        quoting_requests: Array[String], unreadable: Array[Hash[String, String]],
      #|        completeness: Hash[String, untyped] }
      def members_reached(members)
        seen = members_seen(members)
        seen.merge(members: seen[:members].map { MemberReach.new(it).listed })
      end

      # How far each of members' text reached the captured requests, compactly, from one scan, once the folder is
      # guarded; carried names the members an audit carries forward.
      #: (MembersInLoggedRequests, ?carried: Array[String]) -> LoggedRequestReach
      def reach(members, carried: [])
        seen, read_whole = scanned(members)
        LoggedRequestReach.new(seen[:members], scanned: read_whole, unreadable: seen[:unreadable].size, carried:)
      end

      private

      # Where each of members' text was seen, as members_seen gives it, and how many requests the scan read whole.
      #: (MembersInLoggedRequests)
      #|   -> [{ members_by_status: Hash[String, Integer], members: Array[Hash[String, untyped]], orphans: Integer,
      #|        quoting_requests: Array[String], unreadable: Array[Hash[String, String]],
      #|        completeness: Hash[String, untyped] }, Integer]
      def scanned(members)
        refuse_while_unguarded
        scan = @folder.scan
        requests = scan.requests
        matched = scan.matches(members.patterns)
        read = LoggedRequestScanCompleteness.of(scan, matched)
        report = members.report(requests, matched.found, scan.deferred_tools)
        [{ **report, unreadable: read.unreadable, completeness: read.to_h }, requests.size - read.unreadable.size]
      end

      # What has the host write each request's body to the folder: telemetry on, so it logs request bodies, with no
      # exporter, so nothing leaves the machine.
      #: () -> Hash[String, String]
      def capturing
        { "CLAUDE_CODE_ENABLE_TELEMETRY" => "1", "OTEL_METRICS_EXPORTER" => "none", "OTEL_LOGS_EXPORTER" => "none",
          "OTEL_TRACES_EXPORTER" => "none", "OTEL_LOG_RAW_API_BODIES" => "file:#{@folder.absolute(FOLDER::REQUESTS)}" }
      end

      #: (Array[String], bool) -> void
      def refuse_unignored(written, created)
        return if ignored?

        written.each { |name| @folder.remove(name) }
        @folder.remove_if_empty if created
        raise not_ignored
      end

      # Whether git confirms it ignores the folder's own paths and every file already in it.
      #: () -> bool
      def ignored?
        paths = (GUARDED | @folder.files).map { |name| @folder.relative(name) }
        ignored = @files.ignored_paths(paths)
        !ignored.nil? && (paths - ignored).empty?
      end

      #: () -> Error
      def unguarded
        Error.new("request_logging_unguarded",
                  "#{@folder.relative(FOLDER::IGNORE)} is missing, so git may not ignore the logged requests beside it",
                  "A logged request holds the session's whole working context, so it must never reach git. Restore " \
                  "#{@folder.relative(FOLDER::IGNORE)} holding the one line *, then run this again.")
      end

      #: () -> Error
      def not_ignored
        Error.new("request_logging_not_ignored",
                  "git does not confirm that it ignores #{FOLDER::FOLDER}/, so logged requests there could be " \
                  "committed",
                  "A logged request holds the session's whole working context, so it must never reach git. Make this " \
                  "project a git repository with git init if it is not one. If git tracks a file under " \
                  "#{FOLDER::FOLDER}/, stop tracking it with git rm -r --cached #{FOLDER::FOLDER}. Then run this " \
                  "command again.")
      end
    end
  end
end

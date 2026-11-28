# typed: strict
# frozen_string_literal: true

require "time"
require_relative "invocation"
require_relative "prompts"
require_relative "shell_word"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What turning request logging on or off did.
    class RequestLoggingResult
      RELAUNCH = "A host started with the launch file keeps capturing until you relaunch it; the logged requests " \
                 "already captured stay in .principles/request-logging/requests/, which git ignores."
      NEVER_ON = "Request logging was never turned on here, so there is nothing to stop."

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # launch_line starts the host with the launch file for that launch only: a printed line, never an alias, since
      # an alias would capture in every project the user starts the host in; resume_line is the same line resuming a
      # conversation, since a fresh launch starts a new one. explain_to_user is what the agent tells
      # the user before that relaunch: what is logged, who can read it, its cost and how to stop it.
      #: (wrote: Array[String], launch_file: String) -> Hash[String, untyped]
      def turned_on(wrote:, launch_file:)
        launch = "claude --settings #{ShellWord.new(launch_file)}"
        { "status" => "request_logging_on", "wrote" => wrote, "launch_line" => launch,
          "resume_line" => "#{launch} --resume",
          "explain_to_user" => Prompts.text("read-what-reached-the-context/explain-request-logging-to-the-user"),
          "next_action" => "Give the user launch_line to start Claude Code with; capture starts only on that " \
                           "launch, so relaunch the host with it. Each logged request holds the session's whole " \
                           "working context, the files read and every tool result, in a folder git ignores. The " \
                           "launch file sets every telemetry exporter to none for that launch, overriding an " \
                           "exporter the user set up. Turning request logging off deletes no logged request: " \
                           "#{@invocation.in_project("turn-off-request-logging")}" }
      end

      # newest names facts for the agent to judge whether capture is running; it never says a session is capturing.
      #: (sessions: Array[Hash[String, untyped]], orphan_requests: Hash[String, Integer],
      #|  newest_request_written_at: Time?, newest_session_id: String?) -> Hash[String, untyped]
      def shown(sessions:, orphan_requests:, newest_request_written_at:, newest_session_id:)
        { "status" => "logged_requests_shown", "sessions" => sessions, "orphan_requests" => orphan_requests,
          "newest" => { "request_written_at" => newest_request_written_at&.utc&.iso8601,
                        "session_id" => newest_session_id },
          "wrote" => [] }
      end

      #: (removed: Array[String]) -> Hash[String, untyped]
      def removed(removed:) = { "status" => "logged_requests_removed", "removed" => removed, "wrote" => [] }

      #: (wrote: Array[String]) -> Hash[String, untyped]
      def turned_off(wrote:)
        { "status" => "request_logging_off", "wrote" => wrote,
          "next_action" => wrote.empty? ? NEVER_ON : RELAUNCH }
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../views/request_logging_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The switch for request logging, each request the host sends written under .principles/request-logging/,
    # and the read of what was captured there.
    class RequestLogging < Command
      # Each command, by the private method that runs it.
      COMMANDS = { "turn-on-request-logging" => :turned_on,
                   "turn-off-request-logging" => :turned_off,
                   "show-logged-requests" => :shown,
                   "remove-logged-requests" => :removed }.freeze #: Hash[String, Symbol]

      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          operation = COMMANDS[command] or unknown(command)
          send(operation, @project.request_logging, Views::RequestLoggingResult.new(invocation), options)
        end
      end

      private

      #: (Models::RequestLogging, Views::RequestLoggingResult, Hash[String, untyped]) -> Hash[String, untyped]
      def turned_on(logging, result, _options)
        result.turned_on(wrote: logging.turn_on, launch_file: logging.launch_file)
      end

      #: (Models::RequestLogging, Views::RequestLoggingResult, Hash[String, untyped]) -> Hash[String, untyped]
      def turned_off(logging, result, _options) = result.turned_off(wrote: logging.turn_off)

      #: (Models::RequestLogging, Views::RequestLoggingResult, Hash[String, untyped]) -> Hash[String, untyped]
      def shown(logging, result, _options)
        captured = logging.captured
        result.shown(sessions: captured.sessions.map(&:to_h), orphan_requests: captured.orphans.to_h,
                     newest_request_written_at: captured.newest_request_written_at,
                     newest_session_id: captured.newest_session_id)
      end

      #: (Models::RequestLogging, Views::RequestLoggingResult, Hash[String, untyped]) -> Hash[String, untyped]
      def removed(logging, result, options)
        result.removed(removed: logging.remove(keep_sessions: options["keep_sessions"]))
      end
    end
  end
end

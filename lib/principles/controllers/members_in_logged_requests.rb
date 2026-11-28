# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/members_in_logged_requests"
require_relative "../views/members_in_logged_requests_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # show-members-in-logged-requests: which mapped members' text reached each request the host captured under
    # .principles/request-logging/requests/, so a principle is tuned from what reached the context. It
    # writes nothing.
    class MembersInLoggedRequests < Command
      # CommandRoutes routes only show-members-in-logged-requests here.
      # Each member's reach, or with --places every place it was seen, or with --member the places of the members it
      # names alone, or with --short the counts and one line a member rather than the JSON.
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          @tool.feature(command).refuse_while_off
          view = Views::MembersInLoggedRequestsResult.new
          report = report_for(options)
          options["short"] ? view.short(report) : view.result(report)
        end
      end

      private

      # The scan's report in the form options ask for: every place each member --member names was seen, or each
      # member's, or each member's reach.
      #: (Hash[String, untyped])
      #|   -> { members_by_status: Hash[String, Integer], members: Array[Hash[String, untyped]], orphans: Integer,
      #|        quoting_requests: Array[String], unreadable: Array[Hash[String, String]],
      #|        completeness: Hash[String, untyped] }
      def report_for(options)
        named = options["member"]
        return logging.members_seen(mapped.only(named)) if named

        options["places"] ? logging.members_seen(mapped) : logging.members_reached(mapped)
      end

      #: () -> Models::RequestLogging
      def logging = @project.request_logging

      # Every mapped member, to measure.
      #: () -> Models::MembersInLoggedRequests
      def mapped = Models::MembersInLoggedRequests.mapped_in(@project)
    end
  end
end

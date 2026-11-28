# typed: strict
# frozen_string_literal: true

require_relative "controllers/inventory"
require_relative "controllers/principle_listing"
require_relative "controllers/survey"
require_relative "controllers/guidance_search_paths"
require_relative "controllers/member_problems_report"
require_relative "controllers/mapping"
require_relative "controllers/meta_principle_setup"
require_relative "controllers/member_entries"
require_relative "controllers/audit"
require_relative "controllers/answer"
require_relative "controllers/open_correction"
require_relative "controllers/first_audit_brief"
require_relative "controllers/session_start_report"
require_relative "controllers/after_commit_report"
require_relative "controllers/hook_setup"
require_relative "controllers/request_logging"
require_relative "controllers/members_in_logged_requests"
require_relative "controllers/carrier_practices"

module Principles
  # Every command this tool runs, each with its route: the positional words it takes, which CommandLine parses, and
  # the controller that runs it, which CLI hands the parsed line to.
  module CommandRoutes
    # One command's route.
    class Route
      #: Array[String]
      attr_reader :positional
      #: singleton(Controllers::Command)
      attr_reader :controller
      # Whether the command reads a hook's JSON on stdin, as a host passes it to the hook that runs it.
      #: bool
      attr_reader :reads_hook_input

      # positional names each positional argument in order, a trailing ? marking one the command may leave out, and a
      # last NAME... or NAME?... one taking every value from its place on; the rest are named options.
      #: (singleton(Controllers::Command), Array[String], ?reads_hook_input: bool) -> void
      def initialize(controller, positional, reads_hook_input: false)
        @controller = controller
        @positional = positional.freeze #: Array[String]
        @reads_hook_input = reads_hook_input
        freeze
      end
    end

    ROUTES = {
      "list-candidate-files" => Route.new(Controllers::Survey, []),
      "show-candidate-outlines" => Route.new(Controllers::Survey, ["path..."]),
      "add-guidance-search-path" => Route.new(Controllers::GuidanceSearchPaths, %w[glob]),
      "remove-guidance-search-path" => Route.new(Controllers::GuidanceSearchPaths, %w[glob]),
      "list-principles" => Route.new(Controllers::PrincipleListing, []),
      "list-member-problems" => Route.new(Controllers::MemberProblemsReport, %w[id?]),
      "show-principle" => Route.new(Controllers::Inventory, %w[id]),
      "show-audit" => Route.new(Controllers::Audit, %w[id]),
      "list-open-findings" => Route.new(Controllers::Audit, %w[id?]),
      "show-meta-principle-passage" => Route.new(Controllers::MetaPrincipleSetup, []),
      "create-principle" => Route.new(Controllers::Mapping, %w[id]),
      "remove-principle" => Route.new(Controllers::Mapping, %w[id]),
      "change-description" => Route.new(Controllers::Mapping, %w[id]),
      "change-activation" => Route.new(Controllers::Mapping, %w[id]),
      "add-member" => Route.new(Controllers::MemberEntries, %w[id path]),
      "move-member" => Route.new(Controllers::MemberEntries, %w[id member]),
      "change-member-role" => Route.new(Controllers::MemberEntries, %w[id member]),
      "change-member-check" => Route.new(Controllers::MemberEntries, %w[id member]),
      "remove-member-check" => Route.new(Controllers::MemberEntries, %w[id member]),
      "remove-member" => Route.new(Controllers::MemberEntries, %w[id member]),
      "start-audit" => Route.new(Controllers::Audit, %w[id other_ids?...]),
      "submit-answer" => Route.new(Controllers::Answer, %w[request_id?]),
      "show-answer-check" => Route.new(Controllers::Answer, %w[request_id?]),
      "show-open-correction" => Route.new(Controllers::OpenCorrection, %w[id]),
      "show-first-audit-brief" => Route.new(Controllers::FirstAuditBrief, %w[id?]),
      "show-hook-setup" => Route.new(Controllers::HookSetup, []),
      "turn-on-request-logging" => Route.new(Controllers::RequestLogging, []),
      "show-members-in-logged-requests" => Route.new(Controllers::MembersInLoggedRequests, []),
      "turn-off-request-logging" => Route.new(Controllers::RequestLogging, []),
      "show-logged-requests" => Route.new(Controllers::RequestLogging, []),
      "remove-logged-requests" => Route.new(Controllers::RequestLogging, []),
      "show-carrier-practices" => Route.new(Controllers::CarrierPractices, %w[kind]),
      "report-at-session-start" => Route.new(Controllers::SessionStartReport, [], reads_hook_input: true),
      "report-after-commit" => Route.new(Controllers::AfterCommitReport, [], reads_hook_input: true)
    }.freeze #: Hash[String, Route]

    # Each command's positional arguments, in order, as CommandLine takes them.
    POSITIONAL = ROUTES.transform_values(&:positional).freeze #: Hash[String, Array[String]]

    # The controller that runs each command: one per set of commands that change for one reason.
    CONTROLLERS = ROUTES.transform_values(&:controller).freeze #: Hash[String, singleton(Controllers::Command)]
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/evidence_lines_since"
require_relative "../models/loading_decision"
require_relative "../models/other_principles"
require_relative "../models/prior_decision_fields"
require_relative "../models/uncommitted_outside_the_map"
require_relative "../views/loads_to_check_result"
require_relative "../views/open_findings_elsewhere_result"
require_relative "../views/other_principles_unjudged_result"
require_relative "../views/outside_the_map_result"
require_relative "../views/package_since_last_audit_result"
require_relative "../views/prior_findings_result"
require_relative "members_to_assess"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The parts a full audit's request lists beside its members, which FullAuditRequest hands over: each a list the
    # agent reads, with its instruction and its slots in the answer.
    class PartsToRead < Command
      # Each part listed only when it holds something, which start-audit --part answers as empty when it is left out.
      OPTIONAL = [Views::OutsideTheMapResult::PART, Views::PriorFindingsResult::PART,
                  Views::OpenFindingsElsewhereResult::PART, Views::LoadsToCheckResult::PART,
                  Views::PackageSinceLastAuditResult::PART,
                  Views::OtherPrinciplesUnjudgedResult::PART].freeze #: Array[String]

      # audit is the audit asked of the principle's map, listing the members its request lists and audited_files the
      # files its base commit is judged over.
      #: (Models::Project, tool: RunningTool, audit: Models::Audit, listing: MembersToAssess::Listing,
      #|  audited_files: Array[String]) -> void
      def initialize(project, tool:, audit:, listing:, audited_files:)
        super(project, tool: tool)
        @id = audit.map.id #: String
        @audit = audit
        @listing = listing
        @audited_files = audited_files
      end

      # What the agent reads beside the members, in order: the files outside the map that differ from the
      # base commit, which a check and the answer's evidence read as they are now; the prior findings;
      # the findings other principles leave open on members sharing these lines; and the members to
      # check against the activation; each when it lists any; and, on the meta-principle's audit, the release
      # since its last audit and the other principles with members no audit has judged.
      #: (Models::PriorFindings, Hash[String, untyped]?) -> Array[Views::RequestPart]
      def listed(prior, loads)
        map = @audit.map
        [outside_the_map, prior_findings_part(prior),
         Views::OpenFindingsElsewhereResult.new(@listing.open_findings_elsewhere).part,
         loads_part(loads), package_since_last_audit(map),
         other_principles_unjudged(map)].compact
      end

      private

      # The part listing the members to check against the activation, each decision's template printing the
      # placeholders an answer leaves as printed to give none; nil when none is listed.
      #: (Hash[String, untyped]?) -> Views::RequestPart?
      def loads_part(loads)
        Views::LoadsToCheckResult.new(invocation, loads, @id, placeholders: Models::LoadingDecision::PLACEHOLDERS.to_h)
                                 .part
      end

      # The part listing each other principle with members no audit has judged as they are now, as
      # list-member-problems reports them, for the principle whose audit states them; nil for any other.
      #: (Models::Principle) -> Views::RequestPart?
      def other_principles_unjudged(map)
        return unless map.keeps_others_held?

        listed = Models::OtherPrinciples.of(@project, but: map.id).unjudged.map do |other, members|
          Views::PrincipleWithChangedMembers.new(principle_id: other, members: members)
        end
        Views::OtherPrinciplesUnjudgedResult.new(listed).part
      end

      # The part stating the release of principles the last completed audit ran under beside the one now, and
      # whether the passage changed since, for a principle whose audit keeps one; nil for any other.
      #: (Models::Principle) -> Views::RequestPart?
      def package_since_last_audit(map)
        now = @tool.release_kept_by(map) or return
        last = @audit_records.find(map.id)&.last_completed&.package
        Views::PackageSinceLastAuditResult.new(invocation, at_last_audit: last&.version, now: now.version,
                                                           passage_changed: last && now.passage_changed_since?(last),
                                                           mapped: package_parts_mapped(map))
                                          .part
      end

      # Each part of principles an upgrade can change that map's members are, from the hooks every host reads and,
      # where a member's part asks, its text now.
      #: (Models::Principle) -> Array[String]
      def package_parts_mapped(map)
        hooks = @project.hook_commands(Models::HookCommands::ON_EVERY_HOST)
        map.members.package_parts(hooks) { |member| @project.member_text(member.locator) }
      end

      # The part listing the prior findings, in git with each evidence item saying whether its text changed since the
      # commit the audit that left them open was based on, and whether it is found now; nil when there are
      # none.
      #: (Models::PriorFindings) -> Views::RequestPart?
      def prior_findings_part(prior)
        shown = prior.shown { |item, base| Models::EvidenceLinesSince.of(item, since: base, project: @project).facts }
        Views::PriorFindingsResult.new(shown, placeholders: Models::PriorDecisionFields::TEMPLATE_PLACEHOLDERS,
                                              last_audited_commit: prior.last_audited_commit).part
      end

      # The part naming the files outside the map that differ from the base commit, or nil when none do.
      #: () -> Views::RequestPart?
      def outside_the_map
        outside = @history.uncommitted_outside(@audited_files)
        Views::OutsideTheMapResult.new(outside && Models::UncommittedOutsideTheMap.new(outside).shown).part
      end
    end
  end
end

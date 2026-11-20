# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "meta_principle_passage"
require_relative "printed_principle"
require_relative "first_audit"
require_relative "report_hooks_offer"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What show-meta-principle-passage prints: the map its printed add-member writes, the facts of the project's entry
    # files, the one passage any of them would take, and the commands that map the passage once the agent has placed
    # it with the user.
    class MetaPrincipleResult
      # How the printed add-member commands map the passage: heading is the passage's heading, which they name as
      # its member's section, beside role, the role they give that member; step_role is the role they give a
      # passage the project has that carries one of the passage's steps, and place_role the one they give any other
      # place that keeps the principles held, such as a timer or a settings line.
      class PassageMapping
        #: String
        attr_reader :heading, :role, :step_role, :place_role

        #: (heading: String, role: String, step_role: String, place_role: String) -> void
        def initialize(heading:, role:, step_role:, place_role:)
          @heading = heading
          @role = role
          @step_role = step_role
          @place_role = place_role
          freeze
        end
      end

      # mapping is how the printed commands map the passage; in_git says whether a commit can be the member's
      # baseline.
      #: (Invocation, PassageMapping, in_git: bool) -> void
      def initialize(invocation, mapping, in_git:)
        @invocation = invocation
        @mapping = mapping
        @in_git = in_git
        freeze
      end

      # The passage, as the agent pastes it into an entry file, its lines kept.
      #: () -> String
      def passage = MetaPrinciplePassage.new(heading: @mapping.heading).text

      # What the passage presumes of a teammate without principles, given its estimated size.
      #: (Integer) -> String
      def presumes(estimated_tokens)
        Prompts.text("set-principles-up/what-the-passage-presumes", estimated_tokens: estimated_tokens.to_s)
      end

      # Where the passage can go, as the agent places it from: how this run was started and whether the plugin's
      # session-start hook runs in this session, each root entry file's facts, and the passage's text with its size
      # and what it presumes of a teammate without principles.
      class Placement
        #: (runs_from: String, session_start_hook_in_this_session: bool, entry_files: Array[Hash[String, untyped]],
        #|  passage: Hash[String, untyped]) -> void
        def initialize(runs_from:, session_start_hook_in_this_session:, entry_files:, passage:)
          @fields = { "runs_from" => runs_from,
                      "session_start_hook_in_this_session" => session_start_hook_in_this_session,
                      "entry_files" => entry_files, "passage" => passage }.freeze #: Hash[String, untyped]
          freeze
        end

        #: () -> Hash[String, untyped]
        def to_h = @fields

        # The passage's estimated size, which loads in every session that loads the entry file it goes in.
        #: () -> Integer
        def estimated_tokens = @fields.fetch("passage").fetch("estimated_tokens")

        # Whether the plugin's hooks report in this session, so its hook entries need no offer.
        #: () -> bool
        def hooks_run? = @fields.fetch("session_start_hook_in_this_session")
      end

      # The map as the project holds it: already_mapped says the map was there before this run, and
      # members_in_entry_files names its members already in an entry file, by id and path; set_up says the map has a
      # member, so the question asks which keeping step each lacks in place of asking to place the passage.
      class MapInProject
        #: bool
        attr_reader :set_up

        #: (already_mapped: bool, members_in_entry_files: Array[Hash[String, String]], set_up: bool) -> void
        def initialize(already_mapped:, members_in_entry_files:, set_up:)
          @fields = { "already_mapped" => already_mapped,
                      "members_in_entry_files" => members_in_entry_files }.freeze #: Hash[String, untyped]
          @set_up = set_up
          freeze
        end

        #: () -> Hash[String, untyped]
        def to_h = @fields
      end

      # existing_principles lists the project's other principles as list-principles lists them. Outside the plugin,
      # it offers the hook entries that report changed members between audits, as a completed audit does.
      #: (PrintedPrinciple, Placement, MapInProject, existing_principles: Array[Hash[String, untyped]])
      #|  -> Hash[String, untyped]
      def proposal(principle, placement, map_in_project, existing_principles:)
        hook_setup = placement.hooks_run? ? {} : { "hook_setup" => ReportHooksOffer.new(@invocation).to_s }
        { "status" => "question", "principle_id" => principle.id, "map_file" => principle.file,
          "map" => principle.map, **map_in_project.to_h, **placement.to_h, **hook_setup,
          "existing_principles" => existing_principles,
          "question" => map_in_project.set_up ? steps_lacking(principle, placement) : question(principle.id),
          "answer_with" => add_member(principle.id), "next_action" => next_action(principle.id, existing_principles) }
      end

      private

      # What to agree with the user and place, with the command that maps a passage the project has in a step's
      # place, and the one that maps the passage once it is placed.
      #: (String) -> String
      def question(id)
        Prompts.text("set-principles-up/place-the-passage-with-the-user",
                     command: add_member(id), existing: add_existing(id), any_place: add_place(id))
      end

      # Each mapped member's place and role, and which keeping step each lacks, with the passage as one way to add a
      # missing step, at its size, and the command that maps another place.
      #: (PrintedPrinciple, Placement) -> String
      def steps_lacking(principle, placement)
        members = principle.members.map { |member| "- #{member.fetch("id")}: #{member.fetch("role")}" }.join("\n")
        Prompts.text("set-principles-up/name-the-step-each-member-lacks",
                     members: members, command: add_member(principle.id), any_place: add_place(principle.id),
                     estimated_tokens: placement.estimated_tokens.to_s)
      end

      # The add-member that maps any other place that keeps the principles held, by its path and a role naming the
      # step it runs and what starts it.
      #: (String) -> String
      def add_place(id)
        @invocation.in_project("add-member", id, usage: "PATH --role \"#{@mapping.place_role}\"")
      end

      # The add-member that maps a passage the project already has, which carries one of the passage's steps.
      #: (String) -> String
      def add_existing(id)
        @invocation.in_project("add-member", id, usage: "PATH --section \"HEADING\" --role \"#{@mapping.step_role}\"")
      end

      #: (String) -> String
      def add_member(id)
        @invocation.in_project("add-member", id,
                               usage: "ENTRY_FILE --section \"#{@mapping.heading}\" --role \"#{@mapping.role}\"")
      end

      # What follows placing the passage: committing it, which outside git is not the member's baseline, and the
      # first full audit, which waits until the project has a principle of its own to keep held.
      #: (String, Array[Hash[String, untyped]]) -> String
      def next_action(id, existing_principles)
        baseline = if @in_git
                     "Then commit .principles/ and the entry file you changed."
                   else
                     "This principle's first full audit gives the passage's member its baseline, since this project " \
                       "is not in git."
                   end
        [baseline, FirstAudit.new(@invocation, in_git: @in_git)
                             .keeping(id, existing_principles: existing_principles)].join(" ")
      end
    end
  end
end

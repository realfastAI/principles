# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "printed_principle"
require_relative "lines_shared_with_member"
require_relative "consecutive_sections_elsewhere"
require_relative "added_member"
require_relative "map_added_to"
require_relative "activation_in_hand"
require_relative "first_audit"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The JSON results of the commands that write a principle's map, with commands for the invocation running now.
    # PrincipleReadResult prints the reads.
    class MapResult
      # The placeholders each printed command leaves for the agent to fill.
      ADD_MEMBER_USAGE = "PATH [--section \"Exact heading text\"] [--starting-at \"text that occurs once\" " \
                         "[--ending-at \"text occurring once after the opening\"]] [--query '$.description'] " \
                         "--role \"The part it plays\""

      CREATED = "Which files or Markdown sections reinforce this principle? Add each one with the part it plays, " \
                "for example: states the principle, lists the checks, records settled terms, reminds on a timer, " \
                "fails the build. When a member is one item inside a larger file or section, narrow it with " \
                "--starting-at, and --ending-at for more than one line. Add one member per command. Leave out the " \
                "material the members govern."

      # in_git says whether the project is in git, where a committed map is each member's baseline until its first
      # full audit.
      #: (Invocation, in_git: bool) -> void
      def initialize(invocation, in_git:)
        @invocation = invocation
        @in_git = in_git
        freeze
      end

      #: (PrintedPrinciple) -> Hash[String, untyped]
      def created(principle)
        question(principle, CREATED, add_member_command(principle.id))
      end

      # Removal changes an entry rather than writing a file; an untracked deleted map needs no git commit.
      #: (String, file: String) -> Hash[String, untyped]
      def removed(id, file:)
        commit = @in_git ? "If this map was tracked, commit its removal.\n" : ""
        { "status" => "removed", "principle_id" => id, "wrote" => [], "removed" => [file],
          "next_action" => "This map is inactive in routine reports. Any retained findings remain unresolved.\n" \
                           "Inspect a readable retained record, if one exists: " \
                           "#{@invocation.in_project("show-audit", id)}\n" \
                           "#{commit}Inspect the remaining maps: #{@invocation.in_project("list-principles")}" }
      end

      #: (PrintedPrinciple) -> Hash[String, untyped]
      def description_changed(principle)
        question(principle, "Changed the description of #{principle.id}.", start_audit(principle.id))
      end

      # What this tool recorded of when the work is in hand, and what a full audit lists against it, as
      # Models::Activation#full_audit_lists names it.
      #: (PrintedPrinciple, lists: String) -> Hash[String, untyped]
      def activation_changed(principle, lists:)
        question(principle, ActivationInHand.new(principle.activation || {}).recorded(principle.id, lists),
                 start_audit(principle.id), shown: { "activation" => principle.activation })
      end

      # change-activation when the map already held that activation, so it wrote nothing.
      #: (PrintedPrinciple) -> Hash[String, untyped]
      def activation_unchanged(principle)
        question(principle, ActivationInHand.new(principle.activation || {}).unchanged(principle.id),
                 @invocation.in_project("show-principle", principle.id),
                 shown: { "activation" => principle.activation })
      end

      # shared says which members share a line with the new one; added lists them only when there are some, as it
      # carries a check only when one is named. joined is what the result says of the map the member joined.
      #: (PrintedPrinciple, added: Hash[String, untyped], ?shared: LinesSharedWithMember, ?joined: MapAddedTo,
      #|  ?other_maps: Array[ConsecutiveSectionsElsewhere | WholeFileElsewhere | MemberSetsOverlap])
      #|  -> Hash[String, untyped]
      def member_added(principle, added:, shared: LinesSharedWithMember.new, joined: MapAddedTo.new,
                       other_maps: [])
        member = AddedMember.new(added, shared: shared, other_maps: other_maps)
        after = joined.after_member(principle, member: member.id, invocation: @invocation, in_git: @in_git)
        question(principle, "#{member.opening}#{after}".rstrip,
                 add_member_command(principle.id), shown: { "member_count" => principle.members.length })
          .merge("added" => member.to_h.merge(joined.added_facts))
      end

      # add-member --plugin: the member read from an installed plugin, with where it comes from, and that it is
      # read-only and how a finding on it is handled.
      #: (PrintedPrinciple, added: Hash[String, untyped]) -> Hash[String, untyped]
      def plugin_member_added(principle, added:)
        question(principle, "Added #{added.fetch("id")}, read-only: principles never edits a plugin's files, which " \
                            "the plugin's next update replaces, so a finding on it is fixed in the project's own " \
                            "files, deferred upstream or accepted. Add the next member the same way.",
                 add_member_command(principle.id), shown: { "member_count" => principle.members.length })
          .merge("added" => added)
      end

      # add-member's report of the map it started, with the description and activation it wrote, which the agent
      # never typed.
      #: (PrintedPrinciple) -> Hash[String, untyped]
      def map_created(principle)
        { "map_created" => { "description" => principle.description, "activation" => principle.activation } }
      end

      # move-member: the member's old id, and its new id, place and the lines it now spans, not its role or the map,
      # which cost 7.6 KB on a 17-member principle for one member moved.
      #: (PrintedPrinciple, from: String, moved: Hash[String, untyped]) -> Hash[String, untyped]
      def member_moved(principle, from:, moved:)
        id = moved.fetch("id")
        question(principle, "#{id} now spans lines #{moved.fetch("first_line")} to #{moved.fetch("last_line")}" \
                            "#{" (moved from #{from})" unless from == id}; if that is not the passage you meant, " \
                            "move it again. Check the other members, then start the audit.", start_audit(principle.id),
                 shown: { "member" => moved })
      end

      # change-member-check: the stored command is the member's check in the map printed beside this, so the
      # agent can see it byte for byte; the question names that field rather than quoting project text.
      # hidden names each character in the check that prints escaped or not at all.
      #: (PrintedPrinciple, member: String, hidden: Array[String]) -> Hash[String, untyped]
      def check_changed(principle, member:, hidden:)
        done = "#{member} is now enforced by the check named in its map entry. The next audit marks it new or " \
               "changed and asks for a review before it runs; nothing runs it automatically: " \
               "you run it when an audit asks for its result."
        return member_replaced(principle, done: done) if hidden.empty?

        member_replaced(principle, done: "#{done} The check holds characters that print escaped or not at all, " \
                                         "which check_hidden_characters names; make sure each is meant.")
          .merge("check_hidden_characters" => hidden)
      end

      # change-member-role, change-member-check and remove-member-check: done says what changed. This tool cannot
      # tell in git whether a full audit's correction is open, so the next step names both cases, and
      # the other case by what the agent holds: a correction request (one user on 8e5b3f9), which already
      # prints its submit-answer command with its request id, so this does not repeat it.
      # shown is what it prints of the map, as question takes it.
      #: (PrintedPrinciple, done: String, ?shown: Hash[String, untyped]) -> Hash[String, untyped]
      def member_replaced(principle, done:, shown: { "map" => principle.map })
        question(principle, "#{done} Check the other members, then start the audit.\nIf you hold a correction " \
                            "request instead, list this member in the changed_map_entries of the fixed disposition " \
                            "this change fixes, and submit that request's answer.",
                 start_audit(principle.id), shown: shown)
      end

      # change-member-role: the member's id and its new role, the one part that changed, never the whole map, which
      # cost 7.9 KB on a 17-member principle.
      #: (PrintedPrinciple, member: String, role: String) -> Hash[String, untyped]
      def role_changed(principle, member:, role:)
        member_replaced(principle, done: "Changed its role.", shown: { "member" => { "id" => member, "role" => role } })
      end

      # remove-member: the id removed and how many members are left, never the whole map left, which cost 7.9 KB on
      # a 17-member principle; show-principle lists them.
      #: (PrintedPrinciple, removed: String) -> Hash[String, untyped]
      def member_removed(principle, removed:)
        left = principle.map.fetch("members").size
        question(principle, "Removed #{removed}. Add or remove members until the map is right.\n" \
                            "#{FirstAudit.new(@invocation, in_git: @in_git).after_mapping(principle.id)}",
                 add_member_command(principle.id), shown: { "member_removed" => removed, "members_left" => left })
      end

      private

      # shown is what the result prints of the map: the whole map unless the caller names less, as add-member
      # does.
      #: (PrintedPrinciple, String, String, ?shown: Hash[String, untyped]) -> Hash[String, untyped]
      def question(principle, text, answer_with, shown: { "map" => principle.map })
        { "status" => "question", "principle_id" => principle.id, "map_file" => principle.file, **shown,
          "question" => text, "answer_with" => answer_with }
      end

      #: (String) -> String
      def start_audit(id)
        @invocation.in_project("start-audit", id)
      end

      #: (String) -> String
      def add_member_command(id)
        @invocation.in_project("add-member", id, usage: ADD_MEMBER_USAGE)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "member_addition"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The writes to one member's entry in the committed member map: where the member is, the part it plays
    # and the check that enforces it. This tool asks, the agent answers, and this tool writes the map and
    # nothing else.
    class MemberEntries < Command
      # Each command and the method that runs it.
      COMMANDS = {
        "add-member" => :add_member, "move-member" => :move_member,
        "change-member-role" => :change_member_role, "change-member-check" => :change_member_check,
        "remove-member-check" => :remove_member_check, "remove-member" => :remove_member
      }.freeze #: Hash[String, Symbol]

      # Each location option and the name the agent typed it as.
      LOCATION_OPTIONS = { "section" => "--section", "starting_at" => "--starting-at",
                           "ending_at" => "--ending-at", "query" => "--query" }.freeze #: Hash[String, String]

      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, id, options)
        naming_the_executable(rerun: ->(member) { rerun(command, id.to_s, member, options) }) do
          method = COMMANDS[command] or unknown(command)
          send(method, required_id(id), options)
        end
      end

      private

      # command as the agent ran it on principle id, with member in place of the member id it gave, and its options
      # as given, each quoted for a shell and named as the agent typed it: a location by LOCATION_OPTIONS, any other,
      # such as --path or --role, by its own one-word name.
      #: (String, String, String, Hash[String, untyped]) -> String
      def rerun(command, id, member, options)
        flags = options.except("project", "member").flat_map do |name, value|
          [LOCATION_OPTIONS.fetch(name) { "--#{name}" }, value.to_s]
        end
        invocation.in_project(command, id, member, options: flags)
      end

      #: (String, Hash[String, untyped]) -> untyped
      def add_member(id, options)
        started = !@principles.mapped?(id)
        map = @principles.addable(id)
        member = located(options, { "path" => text(options["path"], "PATH") }).merge(played(options))
        addition = handed(MemberAddition, map: map, member: member)
        updated = map.adding(member)
        write_map(updated) do |printed|
          added = addition.printed(printed, added_to: updated)
          started ? added.merge(map_result.map_created(printed)) : added
        end
      end

      # The part a new member plays, and the check that enforces it when one is named.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def played(options)
        role = { "role" => text(options["role"], "--role") }
        options["check"] ? role.merge("check" => text(options["check"], "--check")) : role
      end

      # The member's id and the lines it spans in its file now, so the agent sees what it located.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def span(member)
        { "id" => Models::Member.new(member).id }
          .merge(snapshot(Models::Member.new(member).locator).lines)
      end

      # Points an existing member at a new place (a narrower passage, a renamed heading, an anchor that was
      # lost, or with --path a file that was renamed) without taking it out of the map, so it keeps its key and
      # its audit.
      #: (String, Hash[String, untyped]) -> untyped
      def move_member(id, options)
        map = @principles.find(id)
        old = map.member(text(options["member"], "MEMBER"))
        member = located(options, { "path" => new_path(options, old) })
        moved = span(member)
        write_map(map.moving(Models::Member.new(old).id, member)) do |printed|
          map_result.member_moved(printed, from: Models::Member.new(old).id, moved: moved)
        end
      end

      # The path --path names, or else the member's own.
      #: (Hash[String, untyped], Hash[String, untyped]) -> String
      def new_path(options, old)
        options["path"] ? text(options["path"], "--path") : old.fetch("path")
      end

      #: (String, Hash[String, untyped]) -> untyped
      def change_member_role(id, options)
        map = @principles.find(id)
        target = Models::Member.new(map.member(text(options["member"], "MEMBER"))).id
        write_map(map.changing_role(target, text(options["role"], "--role"))) do |printed|
          map_result.member_replaced(printed, member: target, done: "Changed the role of #{target}.")
        end
      end

      # Names the command that enforces a member, which the audit asks the agent to run.
      #: (String, Hash[String, untyped]) -> untyped
      def change_member_check(id, options)
        map = @principles.find(id)
        target = Models::Member.new(map.member(text(options["member"], "MEMBER"))).id
        check = text(options["check"], "--check")
        changed = map.changing_check(target, check)
        hidden = Models::Member.new(changed.member(target)).check_hidden_characters
        write_map(changed) { |printed| map_result.check_changed(printed, member: target, hidden: hidden) }
      end

      #: (String, Hash[String, untyped]) -> untyped
      def remove_member_check(id, options)
        map = @principles.find(id)
        target = Models::Member.new(map.member(text(options["member"], "MEMBER"))).id
        write_map(map.removing_check(target)) do |printed|
          map_result.member_replaced(printed, member: target,
                                              done: "Removed the check of #{target}; the audit no longer asks for " \
                                                    "its result.")
        end
      end

      #: (String, Hash[String, untyped]) -> untyped
      def remove_member(id, options)
        map = @principles.find(id)
        target = text(options["member"], "MEMBER")
        write_map(map.removing(target)) { |printed| map_result.member_removed(printed, removed: target) }
      end

      # The member's place in its file from --section, --starting-at and --ending-at, checked to resolve.
      #: (Hash[String, untyped], Hash[String, untyped]) -> Hash[String, untyped]
      def located(options, member)
        LOCATION_OPTIONS.each { |key, flag| member[key] = text(options[key], flag) if options[key] }
        place = Models::Member.new(member)
        place.check_location
        @project.locate_for_authoring(place.locator)
        member
      end
    end
  end
end

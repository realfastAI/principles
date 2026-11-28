# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../error"
require_relative "../prose_list"
require_relative "../models/plugin_component"

module Principles
  module Controllers
    # add-member --plugin: a member read from a plugin Claude Code installed, which the project maps but never edits.
    class PluginMemberAddition < Command
      # Maps the file options name in an installed plugin whole, pinning the version installed and the hash of its
      # text, in principle id's map, which it starts when there is none.
      #: (String, Hash[String, untyped]) -> untyped
      def add(id, options)
        refuse_location(options)
        found = installed(options)
        started = !@principles.mapped?(id)
        write_map(@principles.addable(id).adding(found.member(text(options["role"], "--role")))) do |printed|
          added = map_result.plugin_member_added(printed, added: found.added)
          started ? added.merge(map_result.map_created(printed)) : added
        end
      end

      private

      # Refuses the location flags a plugin member would ignore, before anything is read: its file is mapped whole.
      #: (Hash[String, untyped]) -> void
      def refuse_location(options)
        given = MemberEntries::LOCATION_OPTIONS.filter_map { |name, flag| flag if options.key?(name) }
        return if given.empty?

        raise Error.new("plugin_member_located", "#{ProseList.new(given)} cannot locate a plugin member",
                        "A plugin's file is mapped whole, so run add-member --plugin again without " \
                        "#{ProseList.new(given)}.")
      end

      # The file PATH names inside the plugin --plugin names, checked to be a plain path before anything installed
      # is read, then found among the plugins installed for the project.
      #: (Hash[String, untyped]) -> Models::InstalledComponent
      def installed(options)
        component = Models::PluginComponent.new(text(options["path"], "PATH"))
        @project.installed_plugins.holding(text(options["plugin"], "--plugin"), component)
      end
    end
  end
end

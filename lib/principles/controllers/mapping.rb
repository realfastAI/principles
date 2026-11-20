# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/activation"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The writes to what a principle declares as a whole in its committed map: that it exists, its
    # description, and when its work is in hand. This tool asks, the agent answers, and this tool writes
    # the map and nothing else. MemberEntries writes each member's entry.
    class Mapping < Command
      # Each command and the method that runs it.
      COMMANDS = {
        "create-principle" => :create_principle, "change-description" => :change_description,
        "change-activation" => :change_activation, "remove-principle" => :remove_principle
      }.freeze #: Hash[String, Symbol]

      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, id, options)
        naming_the_executable do
          method = COMMANDS[command] or unknown(command)
          send(method, required_id(id), options)
        end
      end

      private

      #: (String, Hash[String, untyped]) -> Hash[String, untyped]
      def remove_principle(id, options)
        map = @principles.find(id)
        @audit_records.refuse_map_removal(id, confirmed: options["confirm"] == true)
        file = @principles.remove(map)
        map_result.removed(id, file: file)
      end

      #: (String, Hash[String, untyped]) -> untyped
      def create_principle(id, options)
        map = @principles.create(id) { text(options["description"], "--description") }
        write_map(map) { |printed| map_result.created(printed) }
      end

      #: (String, Hash[String, untyped]) -> untyped
      def change_description(id, options)
        map = @principles.find(id).describing(text(options["description"], "--description"))
        write_map(map) { |printed| map_result.description_changed(printed) }
      end

      # Records when the principle's work is in hand, as the agent judged it.
      #: (String, Hash[String, untyped]) -> untyped
      def change_activation(id, options)
        activation = Models::Activation.declared(when_files: options["when_files"],
                                                 when_invoked: options["when_invoked"], always: options["always"])
        map = @principles.find(id)
        activated = map.activating(activation)
        return map_result.activation_unchanged(printed_principle(map)).merge("wrote" => []) if activated.same_as?(map)

        write_map(activated) { |printed| map_result.activation_changed(printed, lists: activation.full_audit_lists) }
      end
    end
  end
end

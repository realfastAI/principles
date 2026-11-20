# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/report_hooks"
require_relative "../views/hook_setup_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # show-hook-setup: the hook entries that run report-at-session-start and report-after-commit for a user without
    # the principles plugin, on each host. It writes nothing, since the user's settings are theirs: the agent writes
    # the entries once the user agrees.
    class HookSetup < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, _options)
        naming_the_executable do
          unknown(command) unless command == "show-hook-setup"

          Views::HookSetupResult.new(hosts, principles_on_path: principles_on_path).result
        end
      end

      private

      # What PATH says of the principles each entry runs, when it is not this copy: another version first on PATH, or
      # none there that prints a version; nil when a bare principles runs this copy or one of its version.
      #: () -> String?
      def principles_on_path
        other = @tool.other_on_path(asking: Models::ReportHooks::COMMANDS)
        return (Views::HookSetupResult::NONE_ON_PATH unless @tool.launched_on_path?) unless other

        running = @tool.version
        Views::HookSetupResult.other_on_path(other.path, other.version, running, lacking: other.lacking) if
          other.shadows?(running)
      end

      # Each host's hooks, as plain values.
      #: () -> Array[Hash[String, untyped]]
      def hosts
        Models::ReportHooks::HOSTS.map do |host|
          { "host" => host.name, "file" => host.file, "offered" => host.offered_in(@project),
            "hooks" => host.hooks.map { { "event" => it.event, "matcher" => it.matcher, "command" => it.command } } }
        end
      end
    end
  end
end

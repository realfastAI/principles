# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../prose_list"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What show-hook-setup prints: each host's file and the hook entries that go in it, for the agent to show the user
    # and write only once the user agrees.
    class HookSetupResult
      # The executable each entry runs: principles as found on PATH, since the running executable's path names the
      # installed version, which an upgrade removes, and Codex asks the user to trust a hook again when it changes.
      EXECUTABLE = "principles"

      # What the agent reads when principles did not start, which both commands' exit status 0 never says otherwise.
      FAILED = "principles: principles failed to start, so this session gets no report from it: run it with " \
               "--version to see why."

      # A hook's timeout, in seconds, as each host reads it.
      TIMEOUT = 15

      # What the result says first when no principles on PATH prints a version, so every entry would fail to start.
      NONE_ON_PATH = "No principles on PATH prints its version, so each entry below would print its failure line in " \
                     "every session. Install the principles gem where the hooks' shell finds it before writing them."

      # What the result says first when another version of principles is first on PATH, which each entry would run,
      # and the commands of the entries that copy does not run.
      #: (String, String, String, lacking: Array[String]) -> String
      def self.other_on_path(path, version, running, lacking:)
        runs = if lacking.empty?
                 "which runs both report commands, so each entry would report as #{version} does"
               else
                 "which does not run #{ProseList.new(lacking, conjunction: "or")}, so each entry would print its " \
                   "failure line in every session"
               end
        "The principles on PATH, #{path}, is #{version}, not this #{running}, so each entry below would run " \
          "#{version}, #{runs}. Update or remove that copy before writing them."
      end

      # hosts gives each "host" by name, its "file", why it is "offered" and its "hooks", each with its "event",
      # "matcher" and "command";
      # principles_on_path says what PATH would run in place of this copy, or is nil when it runs this one.
      #: (Array[Hash[String, untyped]], principles_on_path: String?) -> void
      def initialize(hosts, principles_on_path:)
        @hosts = hosts
        @principles_on_path = principles_on_path
        freeze
      end

      # The entries, after what PATH would run in their place, when that is not this copy.
      #: () -> Hash[String, untyped]
      def result
        { **({ "principles_on_path" => @principles_on_path } if @principles_on_path),
          "hosts" => @hosts.map { it.slice("host", "file", "offered").merge("entries" => entries(it)) },
          "next_action" => Prompts.text("set-principles-up/wire-the-report-hooks-with-the-user"), "wrote" => [] }
      end

      private

      # host's entries by event, each one matcher group.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def entries(host)
        { "hooks" => host.fetch("hooks").to_h { [it.fetch("event"), [group(it)]] } }
      end

      # One matcher group, its one handler running hook's command, guarded.
      #: (Hash[String, String]) -> Hash[String, untyped]
      def group(hook)
        command = guarded(hook.fetch("event"), hook.fetch("command"))
        { "matcher" => hook.fetch("matcher"),
          "hooks" => [{ "type" => "command", "command" => command, "timeout" => TIMEOUT }] }
      end

      # command, followed by the echo that runs when it exits other than 0, which it never does once started: plain
      # text at session start, and after a call the hook's JSON, since the agent never reads such a hook's plain
      # stdout.
      #: (String, String) -> String
      def guarded(event, command)
        said = if event == "SessionStart"
                 FAILED
               else
                 JSON.generate({ "hookSpecificOutput" => { "hookEventName" => event, "additionalContext" => FAILED } })
               end
        "#{EXECUTABLE} #{command} || echo '#{said}'"
      end
    end
  end
end

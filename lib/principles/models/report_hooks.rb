# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The hooks that run this tool's two hook commands for a project without the principles plugin, on each host: the
    # file the project's own hooks go in, and the command each event runs. Claude Code runs a hook after a failed shell
    # call under an event of its own; Codex has none, its PostToolUse running after every call.
    class ReportHooks
      # One hook: the event that runs it, the matcher that picks which of the event's runs, and its command.
      class Hook
        #: String
        attr_reader :event, :matcher, :command

        #: (String, String, String) -> void
        def initialize(event, matcher, command)
          @event = event
          @matcher = matcher
          @command = command
          freeze
        end
      end

      # One host's hooks: its name, the file they go in, from the project's root, the hooks, and why its block is
      # offered, as a clause, unless the project holds folder, the host's own, when that is why.
      class Host
        #: String
        attr_reader :name, :file
        #: Array[Hook]
        attr_reader :hooks

        #: (String, String, Array[Hook], offered: String, ?folder: String?) -> void
        def initialize(name, file, hooks, offered:, folder: nil)
          @name = name
          @file = file
          @hooks = hooks.freeze #: Array[Hook]
          @offered = offered
          @folder = folder
          freeze
        end

        # Why its block is offered in project.
        #: (Project) -> String
        def offered_in(project)
          folder = @folder
          folder && project.folder?(folder) ? "since #{folder}/ exists in this project" : @offered
        end
      end

      # The hook at each session's start, from any source, and the one after each shell call.
      SESSION_START = Hook.new("SessionStart", "startup|resume|clear|compact", "report-at-session-start") #: Hook
      AFTER_A_CALL = Hook.new("PostToolUse", "Bash", "report-after-commit") #: Hook

      # The commands the hooks run, once each.
      COMMANDS = [SESSION_START.command, AFTER_A_CALL.command].freeze #: Array[String]

      # Claude Code first, its file the gitignored local one, since a committed one would run for a teammate without
      # this tool and fail every session start of theirs.
      HOSTS = [
        Host.new("Claude Code", ".claude/settings.local.json",
                 [SESSION_START, AFTER_A_CALL, Hook.new("PostToolUseFailure", "Bash", "report-after-commit")],
                 offered: "always, as the host this tool serves first"),
        Host.new("Codex", ".codex/hooks.json", [SESSION_START, AFTER_A_CALL],
                 offered: "always, since this command does not tell which host runs this project's sessions",
                 folder: ".codex")
      ].freeze #: Array[Host]
    end
  end
end

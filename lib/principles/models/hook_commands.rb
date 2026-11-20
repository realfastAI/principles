# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"
require_relative "../data/project_files"
require_relative "report_hooks"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The command hooks a project's settings files declare, and which of them name a file. A command names a file
    # when its command or one of its args gives the file's path from the project root, bare or after the project
    # placeholder, with nothing else joined to either end. That is a fact about the string: this tool does not run
    # the command, and says nothing of whether its output reaches the agent's context. It reads only command
    # handlers, not prompt or agent ones, as the hooks documentation shapes them: event, matcher group, handler.
    class HookCommands
      # The project placeholder before a path, bare, braced or quoted, which stands for the project root.
      PROJECT_DIR = %r{"?\$\{?CLAUDE_PROJECT_DIR\}?"?/} #: Regexp

      # The project settings files whose hooks Claude Code runs in this checkout: the committed one and the local.
      SETTINGS = %w[.claude/settings.json .claude/settings.local.json].freeze #: Array[String]

      # Those and each file a host without the plugin reads the project's own hooks from, as show-hook-setup names
      # them, where a project without the plugin wires this tool's hooks.
      ON_EVERY_HOST = (SETTINGS | ReportHooks::HOSTS.map(&:file)).freeze #: Array[String]

      # A command handler's command as JSON text quotes it, its value's escapes kept.
      COMMAND_VALUE = /"command"\s*:\s*"((?:[^"\\]|\\.)*)"/ #: Regexp

      # The command hooks in each of paths present, the project settings files unless others are given, or the code
      # each unreadable one was refused with.
      #: (Data::ProjectFiles, ?Array[String]) -> HookCommands
      def self.read(files, paths = SETTINGS)
        new(paths.select { |path| files.file?(path) }.to_h do |path|
          [path, files.parse_json(files.read_text(path), path)]
        rescue Error => e
          [path, e.payload.fetch("code")]
        end)
      end

      # settings maps each settings file's path to its parsed JSON, or to the code this tool refused it with.
      #: (Hash[String, untyped]) -> void
      def initialize(settings)
        @settings = settings
        freeze
      end

      # Each command handler that names the file at path, with the settings file and event it is in, and its
      # matcher, command and args as written.
      #: (String) -> Array[Hash[String, untyped]]
      def naming(path)
        named = %r{(?:\A|[\s"'=])(?:\./)?#{Regexp.escape(path)}(?=\z|[\s"';|&)])}
        handlers.select do |entry|
          [entry["command"], *entry["args"]].any? { |text| text.to_s.gsub(PROJECT_DIR, "").match?(named) }
        end
      end

      # Whether the settings file at path holds a command handler that runs this tool's command, as a whole word
      # after a word ending in principles, as the entries show-hook-setup prints run it.
      #: (String, String) -> bool
      def runs?(path, command)
        handlers.any? { |entry| entry["settings"] == path && running?(entry["command"].to_s, command) }
      end

      # Whether a passage of the settings file at path, which the block gives only once the file runs this tool's
      # command, runs it too: a command value the passage quotes whole runs it. A passage is a JSON fragment, not a
      # file to parse, so each value is decoded alone, and one it cuts off or cannot decode runs nothing; nor does
      # a passage the block refuses to give, as when it can no longer be found.
      #: (String, String) { () -> String } -> bool
      def passage_runs?(path, command, &passage)
        runs?(path, command) && command_values(passage.call).any? { |value| running?(value, command) }
      rescue Error
        false
      end

      # Each settings file this tool could not read, or whose hooks are not the documented shape, with why.
      #: () -> Array[Hash[String, String]]
      def not_read
        @settings.filter_map do |path, parsed|
          code = parsed.is_a?(String) ? parsed : ("unexpected_hooks_shape" unless events(parsed))
          { "path" => path, "code" => code } if code
        end
      end

      private

      # Whether a handler's command text runs this tool's command, as a whole word after a word ending in
      # principles.
      #: (String, String) -> bool
      def running?(text, command)
        text.match?(%r{(?:\A|[\s/])principles["']?\s+#{Regexp.escape(command)}(?=\z|[\s"';|&)])})
      end

      # Each command value passage quotes whole, decoded, leaving out one it cannot decode.
      #: (String) -> Array[String]
      def command_values(passage)
        passage.scan(COMMAND_VALUE).flatten.filter_map do |quoted|
          JSON.parse(%("#{quoted}"))
        rescue JSON::ParserError
          nil
        end
      end

      # Every command handler in every readable settings file, in file and declaration order.
      #: () -> Array[Hash[String, untyped]]
      def handlers
        @settings.flat_map do |path, parsed|
          (events(parsed) || []).flat_map do |event, groups|
            groups.flat_map { |group| commands(group).map { |hook| entry(path, event, group, hook) } }
          end
        end
      end

      #: (String, String, Hash[String, untyped], Hash[String, untyped]) -> Hash[String, untyped]
      def entry(path, event, group, hook)
        { "settings" => path, "event" => event, "matcher" => group["matcher"], "command" => hook["command"],
          "args" => hook["args"] }.compact
      end

      # The settings' hooks by event, or nil when they are not the documented shape; none when there are none.
      #: (untyped) -> Hash[String, Array[Hash[String, untyped]]]?
      def events(parsed)
        return nil unless parsed.is_a?(Hash)

        hooks = parsed.fetch("hooks", {})
        return nil unless hooks.is_a?(Hash) && hooks.values.all? { |groups| groups?(groups) }

        hooks
      end

      #: (untyped) -> bool
      def groups?(groups)
        return false unless groups.is_a?(Array)

        groups.all? { |group| group.is_a?(Hash) && group.fetch("hooks", []).is_a?(Array) }
      end

      #: (Hash[String, untyped]) -> Array[Hash[String, untyped]]
      def commands(group)
        group.fetch("hooks", []).select { |hook| hook.is_a?(Hash) && hook["type"] == "command" }
      end
    end
  end
end

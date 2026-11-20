# typed: strict
# frozen_string_literal: true

require_relative "invocation_options"

module Principles
  # The options the plugin's after-commit hook gives list-member-problems, --commits-after and --hook-event,
  # and what is wrong with them as given, which CommandLine refuses as a usage error. list-candidate-files takes
  # --commits-after for a range of its own, so CommandLine checks these on COMMAND alone.
  class AfterCommitHookOptions
    # The events Claude Code runs the after-commit hook on, which --hook-event echoes back to it.
    EVENTS = %w[PostToolUse PostToolUseFailure].freeze #: Array[String]
    # A commit's full sha, SHA-1 or SHA-256, which the hook resolves HEAD@{1} to before passing it.
    FULL_SHA = /\A\h{40}(?:\h{24})?\z/ #: Regexp
    # The command the hook runs, the one these options are checked on.
    COMMAND = "list-member-problems"

    #: (InvocationOptions) -> void
    def initialize(options)
      @after = options.value("commits_after") #: String?
      @event = options.value("hook_event") #: String?
      @short = !options.value("short").nil? #: bool
      freeze
    end

    # What is wrong with the options as given, or nil when they fit or neither is given.
    #: () -> String?
    def fault
      after = @after
      event = @event
      return if after.nil? && event.nil?
      return "--commits-after and --hook-event are given together, for the after-commit hook" unless after && event

      value_fault(after, event) || ("--commits-after prints the hook's JSON, not the --short lines" if @short)
    end

    private

    # What is wrong with either value, or nil when both are ones the hook passes.
    #: (String, String) -> String?
    def value_fault(after, event)
      return "--hook-event takes PostToolUse or PostToolUseFailure, not #{event}" unless EVENTS.include?(event)

      "--commits-after takes a commit's full sha, not #{after}" unless FULL_SHA.match?(after)
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "invocation_options"

module Principles
  # The option list-open-findings --short and list-member-problems --short take from Claude Code's SessionStart hook,
  # --session-start, and what is wrong with it as given, which CommandLine refuses as a usage error.
  class SessionStartOptions
    # The sources Claude Code's SessionStart hook names.
    SOURCES = %w[startup resume clear compact].freeze #: Array[String]

    #: (InvocationOptions) -> void
    def initialize(options)
      @start = options.value("session_start") #: String?
      @short = !options.value("short").nil? #: bool
      freeze
    end

    # What is wrong with the option as given, or nil when it fits or is not given; it shapes only --short's lines.
    #: () -> String?
    def fault
      start = @start or return
      return "--session-start takes startup, resume, clear or compact, not #{start}" unless SOURCES.include?(start)

      "--session-start words only the --short line" unless @short
    end
  end
end

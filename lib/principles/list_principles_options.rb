# typed: strict
# frozen_string_literal: true

require_relative "invocation_options"

module Principles
  # The options choosing what list-principles prints, --lines or --open-findings, and what is wrong with them as
  # given, which CommandLine refuses as a usage error.
  class ListPrinciplesOptions
    COMMAND = "list-principles"

    #: (InvocationOptions) -> void
    def initialize(options)
      @lines = !options.value("lines").nil? #: bool
      @open_findings = !options.value("open_findings").nil? #: bool
      freeze
    end

    # What is wrong with the options as given, or nil when they fit: --lines prints ids alone, so it would drop the
    # open findings asked for without a word.
    #: () -> String?
    def fault
      return unless @lines && @open_findings

      "--lines prints only each principle's id, so it shows no open findings; give one of --lines and --open-findings"
    end
  end
end

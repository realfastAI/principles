# typed: strict
# frozen_string_literal: true

require_relative "invocation_options"

module Principles
  # The options choosing which form list-open-findings prints, --lines or --short, and what is wrong with them
  # as given, which CommandLine refuses as a usage error.
  class ListOpenFindingsOptions
    #: (InvocationOptions) -> void
    def initialize(options)
      @lines = !options.value("lines").nil? #: bool
      @short = !options.value("short").nil? #: bool
      freeze
    end

    # What is wrong with the options as given, or nil when they fit.
    #: () -> String?
    def fault
      "--lines and --short each print a different form of the list; give one" if @lines && @short
    end
  end
end

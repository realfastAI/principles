# typed: strict
# frozen_string_literal: true

require_relative "invocation_options"

module Principles
  # The options choosing what show-principle prints, every member or the one --member names, and what is wrong with
  # them as given, which CommandLine refuses as a usage error.
  class ShowPrincipleOptions
    COMMAND = "show-principle"
    # How a refusal of several --member options says to repair it.
    ONE_OR_NONE = "give one, or none for every member"

    #: (InvocationOptions) -> void
    def initialize(options)
      @members = (options.value("member") || []).size #: Integer
      @loads = !options.value("loads").nil? #: bool
      freeze
    end

    # What is wrong with the options as given, or nil when they fit: --member prints one member, so a second would be
    # dropped without a word, and so would --loads, which adds to the whole map.
    #: () -> String?
    def fault
      return "#{COMMAND} prints one member, but --member was given #{@members} times; #{ONE_OR_NONE}" if @members > 1
      return unless @loads && @members == 1

      "--loads adds when each member's file loads to the whole map, which --member does not print; drop --loads to " \
        "see one member, or --member to see every member's loads"
    end
  end
end

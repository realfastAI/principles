# typed: strict
# frozen_string_literal: true

require_relative "invocation_options"

module Principles
  # The options choosing which form show-members-in-logged-requests prints, --short, --places or --member, and what
  # is wrong with them as given, which CommandLine refuses as a usage error.
  class ShowMembersInLoggedRequestsOptions
    #: (InvocationOptions) -> void
    def initialize(options)
      @places = !options.value("places").nil? #: bool
      @short = !options.value("short").nil? #: bool
      @member = !options.value("member").nil? #: bool
      freeze
    end

    # What is wrong with the options as given, or nil when they fit.
    #: () -> String?
    def fault
      return "--member lists the named members' places, which --short does not print; give one" if @member && @short
      return "--member lists the named members' places, and --places every member's; give one" if @member && @places

      "--places lists every place a member was seen, which --short does not print; give one" if @places && @short
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "invocation_options"

module Principles
  # The options that choose which audit start-audit begins, --member and --write-ups, and the form --as prints
  # it in, and what is wrong with them as given, which CommandLine refuses as a usage error.
  class StartAuditOptions
    # several_ids is whether start-audit was given more than one principle id.
    #: (InvocationOptions, ?several_ids: bool) -> void
    def initialize(options, several_ids: false)
      @several_ids = several_ids
      @members = options.value("member") || [] #: Array[String]
      @member = !@members.empty? #: bool
      @write_ups = !options.value("write_ups").nil? #: bool
      @form = options.value("as") #: String?
      @instruction = !options.value("instruction").nil? #: bool
      @part = !options.value("part").nil? #: bool
      freeze
    end

    # What is wrong with the options as given, or nil when they fit.
    #: () -> String?
    def fault
      return "--member and --write-ups each start a different audit; give one" if @member && @write_ups

      several_ids_fault || member_fault || part_fault || instruction_fault || form_fault
    end

    private

    # Several principle ids, which only an acknowledgement of members they each map spans; nil otherwise.
    #: () -> String?
    def several_ids_fault
      return unless @several_ids && !@member

      "several principle ids start one acknowledgement of the members they map, with --member; give one id for " \
        "any other audit"
    end

    # A member given twice, which the agent would judge once; nil when each is given once.
    #: () -> String?
    def member_fault
      twice = @members.find { |member| @members.count(member) > 1 } or return
      "--member #{twice} is given twice; give each member once"
    end

    # --part prints one part of a full audit's request, or beside --as template one member's slot of its answer; nil
    # when nothing beside it prints another output.
    #: () -> String?
    def part_fault
      return unless @part

      other = other_audit || ("the whole field --instruction prints" if @instruction)
      "--part prints one part of a full audit's request, not of #{other}" if other
    end

    # --instruction prints one field of a full audit's request whole; nil when nothing beside it prints
    # another output.
    #: () -> String?
    def instruction_fault
      return unless @instruction

      other = other_output
      "--instruction prints one field of a full audit's request, not of #{other}" if other
    end

    # What --as, --member or --write-ups prints instead of a full audit's request, which --part and --instruction each
    # read from; nil when none is given.
    #: () -> String?
    def other_output
      @form ? "the answer --as template prints" : other_audit
    end

    # What --member or --write-ups starts instead of a full audit; nil when neither is given.
    #: () -> String?
    def other_audit
      if @member then "the one-member audit --member starts"
      elsif @write_ups then "the repoint --write-ups starts"
      end
    end

    # --as template prints a full audit's answer alone, or a one-member audit's, the one form
    # built so far; nil when it fits.
    #: () -> String?
    def form_fault
      form = @form or return
      return "--as takes template, the answer alone, not #{form}" unless form == "template"

      "--as template prints a full or one-member audit's answer, not one --write-ups starts" if @write_ups
    end
  end
end

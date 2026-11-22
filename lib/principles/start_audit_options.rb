# typed: strict
# frozen_string_literal: true

require_relative "invocation_options"

module Principles
  # The options that choose which audit start-audit begins, --member or --open-findings, and the form
  # --as prints it in, and what is wrong with them as given, which CommandLine refuses as a usage error.
  class StartAuditOptions
    # The part that prints the answer to fill bare, saved as it stands, so no other part may print beside it.
    TEMPLATE_PART = "response_template" #: String
    # Each option that starts an audit other than a full one, by its key among the options, and its flag.
    AUDITS = { "member" => "--member",
               "open_findings" => "--open-findings" }.freeze #: Hash[String, String]

    # several_ids is whether start-audit was given more than one principle id.
    #: (InvocationOptions, ?several_ids: bool) -> void
    def initialize(options, several_ids: false)
      @several_ids = several_ids
      @members = options.value("member") || [] #: Array[String]
      @audits = AUDITS.reject { |key, _| options.value(key).nil? }.values #: Array[String]
      @form = options.value("as") #: String?
      @instruction = !options.value("instruction").nil? #: bool
      @parts = options.value("part") || [] #: Array[String]
      @part = !@parts.empty? #: bool
      freeze
    end

    # What is wrong with the options as given, or nil when they fit.
    #: () -> String?
    def fault
      audits_fault || several_ids_fault || member_fault || part_fault || instruction_fault || form_fault
    end

    private

    # Two of the options that each start a different audit; nil when at most one is given.
    #: () -> String?
    def audits_fault
      "#{@audits.first(2).join(" and ")} each start a different audit; give one" if @audits.size > 1
    end

    # Whether flag, one of AUDITS, was given.
    #: (String) -> bool
    def audit?(flag) = @audits.include?(flag)

    # Several principle ids, which only an acknowledgement of members they each map spans; nil otherwise.
    #: () -> String?
    def several_ids_fault
      return unless @several_ids && !audit?("--member")

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
      return "--part prints one part of a full audit's request, not of #{other}" if other

      return unless @parts.include?(TEMPLATE_PART) && @parts.size > 1

      "--part #{TEMPLATE_PART} prints the bare answer to save as it stands; give it alone"
    end

    # --instruction prints one field of a full audit's request whole; nil when nothing beside it prints
    # another output.
    #: () -> String?
    def instruction_fault
      return unless @instruction

      other = other_output
      "--instruction prints one field of a full audit's request, not of #{other}" if other
    end

    # What --as, --member or --open-findings prints instead of a full audit's request, which --part and --instruction
    # each read from; nil when none is given.
    #: () -> String?
    def other_output
      @form ? "the answer --as template prints" : other_audit
    end

    # What --member or --open-findings starts instead of a full audit; nil when neither is given.
    #: () -> String?
    def other_audit
      if audit?("--member") then "the one-member audit --member starts"
      elsif audit?("--open-findings") then "the decision --open-findings starts"
      end
    end

    # --as template prints an audit's answer alone, the one form built so far; nil when it fits.
    #: () -> String?
    def form_fault
      form = @form or return
      "--as takes template, the answer alone, not #{form}" unless form == "template"
    end
  end
end

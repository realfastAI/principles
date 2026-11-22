# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "acknowledgement"
require_relative "assessment_answer"
require_relative "disposition_placeholders"
require_relative "loading_decision"
require_relative "member_assessments"
require_relative "named_placeholder"
require_relative "prior_decision_fields"
require_relative "recent_decision"
require_relative "refusal_before_shape"
require_relative "reported_check"
require_relative "shape_problems_beside"

module Principles
  module Models
    # The text in an answer that ends as this tool's placeholders end, "Leave as printed ...", "else leave" or "else
    # kept", or is a placeholder some template of this release prints, but is none the request's own template
    # printed: another template's placeholder, as an answer filled from an older template and repaired field by field
    # keeps it, which no other check refuses in free text, or as a reason copied from a correction's template
    # into an acknowledgement's. It reads the ending alone for older wordings, so the agent's own text ending
    # so is refused too, and the repair says to reword it.
    class OtherTemplatesPlaceholders
      include RefusalBeforeShape

      # How every placeholder of this tool's templates ends, in this release and earlier ones, one of which said
      # "; leave as printed otherwise" as a clause, which "to leave as printed" in prose is not.
      ENDING = /((\bLeave|; leave) (\S+ ){0,2}as printed[^.]*|\belse (leave|kept))\.?\z/ #: Regexp

      # Every string a JSON value holds, at any depth, by its JSON pointer: the one walk over a template and an
      # answer alike.
      class Strings
        #: (untyped) -> void
        def initialize(value)
          @by_pointer = {} #: Hash[String, String]
          gather(value, "")
          @by_pointer.freeze
          freeze
        end

        #: Hash[String, String]
        attr_reader :by_pointer

        private

        #: (untyped, String) -> void
        def gather(value, pointer)
          case value
          when String then @by_pointer[pointer] = value
          when Hash then value.each { |key, each| gather(each, "#{pointer}/#{escaped(key)}") }
          when Array then value.each_with_index { |each, index| gather(each, "#{pointer}/#{index}") }
          end
        end

        # key as a JSON pointer writes it.
        #: (String) -> String
        def escaped(key) = key.gsub("~", "~0").gsub("/", "~1")
      end

      # Every placeholder a template of this release prints, from the model that owns each: the full audit's member
      # assessment, collective assessment, recent decision, check result, loading decision and prior finding
      # decision, the correction's disposition, and the one-member audit's acknowledgement. Its spec fails on a
      # placeholder constant in models/ missing here.
      KNOWN = [
        MemberAssessments::PLACEHOLDER, MemberAssessments::NAMED_PLACEHOLDER, AssessmentAnswer::COLLECTIVE_PLACEHOLDER,
        RecentDecision::PLACEHOLDERS.to_h,
        ReportedCheck::PLACEHOLDERS.to_h, ReportedCheck::UNCHANGED_PLACEHOLDERS.to_h,
        LoadingDecision::PLACEHOLDERS.to_h, PriorDecisionFields::TEMPLATE_PLACEHOLDERS,
        DispositionPlaceholders::TEMPLATE_PLACEHOLDERS, DispositionPlaceholders::ACTION_PLACEHOLDER,
        AcknowledgementPlaceholders::PLACEHOLDERS.to_h, AcknowledgementPlaceholders::EXIT_STATUS_PLACEHOLDER
      ].then { Strings.new(it).by_pointer.values.to_set }.freeze #: Set[String]

      # Every placeholder a template of this release prints naming its slot's id, for any id or as printed before
      # it named one.
      NAMED = [MemberAssessments::ASSESSMENT, *DispositionPlaceholders::NAMED,
               *AcknowledgementPlaceholders::PLACEHOLDERS.named].freeze #: Array[NamedPlaceholder]

      # Each string in template, a request's template as printed, which its answer may send back; start_from says
      # where that template is printed, as RequestId#answer_to_fill gives it.
      #: (untyped, start_from: String) -> OtherTemplatesPlaceholders
      def self.besides(template, start_from:)
        new(Strings.new(template).by_pointer.values, start_from:)
      end

      # printed is the placeholders the request's own template printed, which an answer may leave as printed, each
      # with NamedPlaceholder::SLOT where it names its slot's id, for any id, and start_from where that template is
      # printed.
      #: (Array[String], start_from: String) -> void
      def initialize(printed, start_from:)
        @printed = printed
        @printed_named = printed.select { it.include?(NamedPlaceholder::SLOT) }
                                .map { NamedPlaceholder.new(it, before: it) } #: Array[NamedPlaceholder]
        @repair = "Start from #{start_from}, or replace each field named with your own text; if one is your own " \
                  "text, reword its ending" #: String
      end

      # Refuses answer in one refusal naming every field holding another template's placeholder, as "The answer": the
      # agent holds its file's path, which cost context in every repair. It names each of shape_problems at
      # another field too, so both slips take one repair.
      # @override
      #: (untyped, String, Array[Hash[String, String]]) -> void
      def refuse_in(answer, _source, shape_problems)
        found = Strings.new(answer).by_pointer.select { |_, text| other?(text) }.keys
        return if found.empty?

        elsewhere = ShapeProblemsBeside.new(shape_problems, named: found)
        raise Error.new("invalid_answer", elsewhere.message(MESSAGE),
                        "#{elsewhere.repair(@repair, "; repair each other field listed")}.",
                        fields: found.map { { "pointer" => it, "problem" => PROBLEM } } + elsewhere.fields)
      end

      MESSAGE = "The answer holds text another template printed as a placeholder" #: String

      PROBLEM = "ends as a placeholder does, but is none this request's template printed" #: String

      private

      # Whether text ends as a placeholder does, or is one another template prints, but is none printed.
      #: (String) -> bool
      def other?(text) = (known?(text) || NAMED.any? { it.left?(text) }) && !printed?(text)

      # Whether the request's own template printed text, a slot's id in any named placeholder.
      #: (String) -> bool
      def printed?(text) = @printed.include?(text) || @printed_named.any? { it.left?(text) }

      # Whether text ends as a placeholder does, or is one a model's constant holds.
      #: (String) -> bool
      def known?(text) = text.match?(ENDING) || KNOWN.include?(text)
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_fields"
require_relative "answer_place"
require_relative "answer_text"
require_relative "fix_only_fields"
require_relative "waits_on"
require_relative "write_up_pointer"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One disposition of a correction answer: the action the agent chose for one finding, why, its evidence and
    # where it is written up, and the members a fix claims it changed. The agent's AnswerFields check each field
    # and locate each piece of evidence in the project. Its readers read what the agent gave, so callers ask them
    # only once CorrectionAnswer has checked every disposition, and found none of its fields unfinished, its action
    # among them.
    class Disposition
      ACTIONS = %w[fixed deferred accepted disagreed].freeze #: Array[String]

      # A field the agent left unfinished: empty, the template's placeholder, the answer guide's sample, or
      # an action not one of the four. It says where it sits in the answer and what to write there, which one
      # refusal lists beside every other.
      class UnfinishedField
        #: String
        attr_reader :repair

        #: (AnswerPlace, String, problem: String, repair: String) -> void
        def initialize(place, name, problem:, repair:)
          @place = place
          @name = name
          @problem = problem
          @repair = repair
          freeze
        end

        # Whose field it is, such as "Finding F1 reason".
        #: () -> String
        def to_s = "#{@place.subject} #{@name}"

        # Its entry in the refusal's fields, as a malformed answer's are.
        #: () -> Hash[String, String]
        def field = { "pointer" => @place.pointer, "problem" => @problem }
      end

      # A text field the agent must write: the placeholder the correction template leaves in it, which an answer may
      # not send back unchanged, and what to write instead; reassessment applies only to a fix.
      class TextField
        #: String
        attr_reader :placeholder

        #: (placeholder: String, repair: String) -> void
        def initialize(placeholder:, repair:)
          @placeholder = placeholder
          @repair = repair
          freeze
        end

        # The field named name, at place, when value leaves it empty, as the placeholder or as sample,
        # the answer guide's illustration of this field for the disposition's action, if it gives one.
        #: (untyped, AnswerPlace, String, sample: String?) -> UnfinishedField?
        def left_in(value, place, name, sample:)
          problem = if !AnswerText.new(value).written? then "must be a nonempty string"
                    elsif value == @placeholder then "is the template's placeholder, unchanged"
                    elsif value == sample then SAMPLE_UNCHANGED
                    end
          UnfinishedField.new(place, name, problem:, repair: @repair) if problem
        end
      end

      # The problem with a field the agent gave back as the answer guide's sample.
      SAMPLE_UNCHANGED = "is the answer guide's sample, unchanged" #: String

      TEXT_FIELDS = {
        "reason" => TextField.new(placeholder: "Why, and what remains",
                                  repair: "Write why you chose this action and what remains."),
        "reassessment" => TextField.new(placeholder: "fixed only: how the changed members now carry the " \
                                                     "principle. Leave as printed otherwise",
                                        repair: "Write how the changed members now carry the principle.")
      }.freeze #: Hash[String, TextField]
      # The placeholder in each field, which the template prints.
      PLACEHOLDERS = TEXT_FIELDS.transform_values(&:placeholder).freeze #: Hash[String, String]
      # What action takes, said where it is written when the correction's answer is printed with no answer guide
      # beside it, as show-answer-check prints it. It is help, never an action, so it is left unchosen.
      ACTION_PLACEHOLDER = "One of fixed, deferred, accepted or disagreed, each with a reason: fixed lists " \
                           "changed_members for current text changes, optional removed_members for map removals, " \
                           "and evidence and gives a reassessment; deferred gives recorded_at, " \
                           "where the write-up is, and may give waits_on; any other action leaves changed_members, " \
                           "evidence and reassessment as printed" #: String
      # Every placeholder a correction's template prints: each text field's, and the action's.
      TEMPLATE_PLACEHOLDERS = PLACEHOLDERS.merge("action" => ACTION_PLACEHOLDER).freeze #: Hash[String, String]

      # at is the disposition's place in the answer, such as /dispositions/0, which a refusal about its pointers names.
      # samples is the answer guide's disposition for each action, whose text illustrates each field.
      #: (untyped, AnswerFields, at: String, samples: Hash[String, untyped]) -> void
      def initialize(disposition, fields, at:, samples:)
        @disposition = disposition
        @fields = fields
        @samples = samples
        @place = AnswerPlace.new(at, "Finding #{disposition["finding_id"]}") #: AnswerPlace
        freeze
      end

      #: () -> untyped
      def finding_id = @disposition["finding_id"]

      # The disposition as the agent gave it.
      #: () -> untyped
      def to_h = @disposition

      #: () -> String
      def action = @disposition.fetch("action")

      #: () -> bool
      def fixed? = action == "fixed"

      # The members a fix says it changed; none from a disposition that omits them, as one not fixed may.
      #: () -> Array[String]
      def changed_members = @disposition.fetch("changed_members", [])

      # The file where the finding is written up, if anywhere.
      #: () -> String?
      def recorded_path = recorded_at&.path

      # What the audit record keeps of this disposition beside its finding: the action, and why a finding left
      # unfixed was left so, which a fix's reassessment answers instead; where the finding is written up and
      # what a deferral waits on, when given.
      #: () -> Hash[String, untyped]
      def recorded_outcome
        { "action" => action, "reason" => (@disposition["reason"] unless fixed?), "recorded_at" => recorded_at&.to_h,
          "waits_on" => @disposition["waits_on"] }.compact
      end

      # Where the finding is written up, if anywhere, as checked_fields located it.
      #: () -> WriteUpPointer?
      def recorded_at
        fields = @disposition["recorded_at"]
        WriteUpPointer.new(fields) if fields
      end

      # Each field this disposition leaves for the agent still: an action that is not one of the four, the reason
      # left empty, as the template's placeholder or as the answer guide's sample, and so a fix's reassessment,
      # which applies to no other action, and a waits_on left as the guide's sample.
      #: () -> Array[UnfinishedField]
      def unfinished = [*unchosen_action, *unwritten_text, *waits_on_left_as_sample]

      # The members this disposition claims it changed, refusing it unless its other fields are sound: only a fix
      # claims any, and each must be among the members that changed. CorrectionAnswer has checked its action and
      # that it wrote each field.
      #: (Array[String]) -> Array[untyped]
      def claimed_members(changed)
        action = @disposition["action"]
        checked_fields
        members = @fields.array(fix_fields.list("changed_members"), "changed_members")
        entries = @disposition.fetch("changed_map_entries", []) + @disposition.fetch("removed_members", [])
        action == "fixed" ? fixed_members(members, entries, changed) : fix_fields.unclaimed(members, entries)
      end

      private

      # The template leaves each action null, or as its placeholder, since choosing it is the agent's call; a null,
      # placeholder or unknown one is left for the agent, with the four to choose from.
      #: () -> UnfinishedField?
      def unchosen_action
        action = @disposition["action"]
        return if ACTIONS.include?(action)

        unchosen = action.nil? || action == ACTION_PLACEHOLDER
        problem = unchosen ? "is not chosen" : "is #{action.inspect}, not one of the four"
        UnfinishedField.new(@place.child("action"), "action",
                            problem:, repair: "Set its action to one of fixed, deferred, accepted or disagreed.")
      end

      # The reason, and a fix's reassessment, when left empty, as the template's placeholder or as the
      # answer guide's sample for this action.
      #: () -> Array[UnfinishedField]
      def unwritten_text
        action = @disposition["action"]
        required = action == "fixed" ? TEXT_FIELDS : TEXT_FIELDS.slice("reason")
        required.filter_map do |name, field|
          field.left_in(@disposition[name], @place.child(name), name, sample: @samples.dig(action, name))
        end
      end

      # A deferral's waits_on left as the answer guide's sample, which illustrates the line without saying whom the
      # finding waits on. It is one line, so WaitsOn would keep it.
      #: () -> UnfinishedField?
      def waits_on_left_as_sample
        sample = @samples.dig(@disposition["action"], "waits_on")
        return unless sample && @disposition["waits_on"] == sample

        UnfinishedField.new(@place.child("waits_on"), "waits_on", problem: SAMPLE_UNCHANGED, repair: WaitsOn::REPAIR)
      end

      # A fix's claimed members, each of which must have changed. A fix may claim no member's text when it
      # claims a map entry instead, which DeclaredMapChanges has checked changed.
      #: (Array[untyped], Array[untyped], Array[String]) -> Array[untyped]
      def fixed_members(members, entries, changed)
        return members unless (members.empty? && entries.empty?) || (members - changed).any?

        raise Error.new("claimed_change_missing",
                        "Finding #{finding_id} claims changes its members do not show: #{members.join(", ")}",
                        "Make the authorised change and reassess it, or record a deferral.")
      end

      # The disposition's evidence and recorded_at, which a deferral must give, if only as null, and the
      # one line a deferral may give saying what it waits on.
      #: () -> void
      def checked_fields
        locate_pointers
        unrecorded_deferral if @disposition["action"] == "deferred" && !@disposition.key?("recorded_at")
        WaitsOn.new(@disposition["waits_on"], action: @disposition["action"])
               .check(code: "invalid_disposition", subject: "Finding #{finding_id}")
      end

      #: () -> FixOnlyFields
      def fix_fields = FixOnlyFields.new(@disposition, left_reassessment: PLACEHOLDERS.fetch("reassessment"))

      # Each piece of evidence, and where the finding is written up, located in the project.
      #: () -> void
      def locate_pointers
        fix_fields.check_removal_evidence if fixed?
        @fields.evidence(fix_fields.list("evidence"), @place.child("evidence"))
        @fields.pointer(@disposition["recorded_at"], @place.child("recorded_at")) if @disposition["recorded_at"]
      end

      # A deferral must say where it is written up, or null, so an answer reused from before recorded_at existed
      # cannot drop the pointer silently.
      #: () -> bot
      def unrecorded_deferral
        raise Error.new("invalid_disposition", "Deferred finding #{finding_id} has no recorded_at",
                        "Set recorded_at to where the finding is written up, as {\"path\": ..., \"heading\": ...}, " \
                        "or to null when it is written up nowhere.")
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_place"
require_relative "disposition_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The part of a finding that a fix settles only in part, which the fix leaves unfixed: raised as a finding of its
    # own, under the id the agent gives it, deferred or accepted as a disposition is, so the record keeps both the
    # part fixed and the part still open, rather than deferring the whole finding. Its outcome is checked as the
    # disposition of that new finding.
    class UnfixedPart
      # What an unfixed part may be left as: open, since the part fixed belongs to the fix itself.
      ACTIONS = %w[deferred accepted].freeze #: Array[String]

      # part is the unfixed_part the disposition fixing in part gives, at place in the answer; outcome is part as
      # the new finding's own disposition.
      #: (Hash[String, untyped], of: Disposition, outcome: Disposition, place: AnswerPlace) -> void
      def initialize(part, of:, outcome:, place:)
        @part = part
        @of = of
        @outcome = outcome
        @place = place
        freeze
      end

      # The id of the finding it raises, as the agent gave it.
      #: () -> untyped
      def id = @part["id"]

      # Its problem and reason when left empty or as the question's example, then each other field its outcome
      # leaves for the agent still, as a disposition's, refusing it first when it is fixed or disagreed, which leave
      # nothing open.
      #: () -> Array[UnfinishedField]
      def unfinished
        action = @part["action"]
        if (Disposition::ACTIONS - ACTIONS).include?(action)
          refuse("/action", "is #{action.inspect}, not deferred or accepted",
                 "Set its action to deferred or accepted; a part fixed too belongs to the fix itself.")
        end
        own = DispositionPlaceholders::UNFIXED_TEXT_FIELDS.filter_map do |name, field|
          field.left_in(@part[name], @place.child(name), name, sample: nil)
        end
        [*own, *@outcome.unfinished].uniq { it.field.fetch("pointer") }
      end

      # Refuses it unless it belongs to a fix, and its pointers and waits_on unless they are sound, as a disposition's.
      #: () -> void
      def check
        unless @of.fixed?
          refuse("", "is only for a fix, and this disposition is #{@of.action}", "Leave unfixed_part out.")
        end
        @outcome.claimed_members([])
      end

      # The finding it raises from finding, the one its fix settles in part: finding's members and evidence, with its
      # own id, problem and outcome; refused when taken, the ids of the record's other findings, holds its id.
      #: (Hash[String, untyped], Array[untyped]) -> Hash[String, untyped]
      def raised_from(finding, taken)
        if taken.include?(id)
          refuse("/id", "takes the id #{id}, which another finding has",
                 "Give it an id that no other finding in this audit's record has.")
        end
        { "id" => id, **finding.slice("member_ids", "evidence"), "problem" => @part.fetch("problem"),
          **@outcome.recorded_outcome }
      end

      private

      # Refuses what sits at pointer, inside the unfixed part, with problem and repair.
      #: (String, String, String) -> bot
      def refuse(pointer, problem, repair)
        message = "Finding #{@of.finding_id}'s unfixed_part #{problem}"
        raise Error.new("invalid_disposition", message, repair,
                        fields: [{ "pointer" => "#{@place.pointer}#{pointer}", "problem" => message }])
      end
    end
  end
end

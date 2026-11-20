# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "answer_fields"
require_relative "answer_place"
require_relative "answer_text"
require_relative "first_raised_claim"
require_relative "kept_prior_finding"
require_relative "open_finding"
require_relative "still_holds_restatement"
require_relative "prior_decision_fields"
require_relative "waits_on"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One decision on a prior finding the request listed, checked against that finding and this audit's
    # new findings. Whether the finding still holds is the agent's judgement; this tool checks the decision's shape.
    class PriorFindingDecision
      KINDS = %w[still_holds resolved withdrawn raised_again].freeze
      CLOSING = %w[resolved withdrawn].freeze
      # The actions a still_holds decision may keep a finding open with, each with what changing to it needs.
      OPEN_ACTIONS = { "deferred" => "a reason and recorded_at, null when written up nowhere",
                       "accepted" => "a reason" }.freeze #: Hash[String, String]
      # What the completed result shows of each closed finding.
      CLOSED_FIELDS = %w[finding_id decision reason evidence].freeze
      REPAIR = "Decide it still_holds, raised_again with as, or resolved or withdrawn with a one-line reason."
      # finding is the prior finding as its record left it open; at is the decision's place in the answer, such as
      # /prior_finding_decisions/0, which a refusal about its pointers names; members are the map's members now, which
      # a kept finding's members must still be among.
      #: (Hash[String, untyped], OpenFinding, Array[String], at: String, members: PrincipleMembers) -> void
      def initialize(decision, finding, new_ids, at:, members:)
        @decision = PriorDecisionFields::PLACEHOLDERS.given(decision) #: Hash[String, untyped]
        @finding = finding
        @new_ids = new_ids
        @members = members
        @id = finding.id #: String
        @place = AnswerPlace.new(at, "Prior finding #{@id}") #: AnswerPlace
        freeze
      end

      # Refuses the decision unless its kind, reason, as, any evidence of a fix and any restated problem or pointer
      # are sound. locate checks that each evidence pointer and a new recorded_at resolve, as a deferral's is checked.
      #: (^(Locator) -> void) -> void
      def check(locate)
        kind = @decision["decision"]
        invalid("#{kind.inspect} is not a decision") unless KINDS.include?(kind)
        kind == "still_holds" ? holds : closed_or_raised(kind)
        pointers_as_text
        fix_shown(locate)
        new_action
        StillHoldsRestatement.new(@decision, @finding, @place, refuse: refusal).check(locate)
        WaitsOn.new(@decision["waits_on"], action: kept_action).check(code: "invalid_decision",
                                                                      subject: "Prior finding #{@id}")
      end

      # The prior finding it decides, as its record left it open.
      #: OpenFinding
      attr_reader :finding

      # What it decides: still_holds, resolved, withdrawn or raised_again.
      #: () -> String
      def kind = @decision.fetch("decision")

      # The id of the new finding a raised_again decision raises it as.
      #: () -> String
      def raised_as = @decision.fetch("as")

      # The decision as the completed result shows a closed finding.
      #: () -> Hash[String, untyped]
      def closed = @decision.slice(*CLOSED_FIELDS)

      # The finding a still_holds decision keeps, against the map's members now. Its problem_evidence is read with an
      # empty list as none given: the template starts a marked finding's decision with one, which an agent leaves in
      # whatever it decides.
      #: () -> KeptPriorFinding
      def kept = KeptPriorFinding.new(@decision, @finding, @members)

      # The earlier first_raised_at this decision claims, if any, to check against the record it cites.
      #: () -> FirstRaisedClaim
      def first_raised_claim = FirstRaisedClaim.new(@decision, @finding)

      private

      # Refuses text, other than its placeholder, in a field that takes pointers, which the schema lets be text only
      # so the placeholder can be left.
      #: () -> void
      def pointers_as_text
        field = PriorDecisionFields::POINTERS.find { |name| @decision[name].is_a?(String) } or return
        invalid("#{field} is text, not pointers into the project",
                "Give #{field} as pointers, such as {\"path\": ..., \"heading\": ...}, or leave its placeholder as " \
                "printed.")
      end

      # A still_holds decision may make its finding deferred or accepted, with a one-line reason, and a deferral
      # says where it is written up, if only as null, as a correction's does.
      #: () -> void
      def new_action
        action = @decision["action"] or return
        unless @decision["decision"] == "still_holds"
          invalid("only still_holds may give action", "Drop action from #{@id}'s decision, or decide it still_holds.")
        end
        invalid("still_holds may make it only deferred or accepted") unless OPEN_ACTIONS.key?(action)
        changed_action(action)
      end

      #: (String) -> void
      def changed_action(action)
        already(action) if action == @finding.action
        invalid("a new action needs a one-line reason") unless one_line_reason?
        unrecorded_deferral if action == "deferred" && !@decision.key?("recorded_at")
      end

      # The template prints action for every finding, so it may be given the action its finding has: the repair
      # names both ways on, keeping it or changing it to the other (dogfood D6).
      #: (String) -> bot
      def already(action)
        other, needs = OPEN_ACTIONS.find { |open, _| open != action }
        invalid("it is already #{action}", "To keep #{@id} #{action}, leave action as printed or drop it; " \
                                           "to change it, give #{other} with #{needs}.")
      end

      #: () -> bot
      def unrecorded_deferral
        invalid("deferring it needs recorded_at, or null when it is written up nowhere",
                "Set recorded_at to where #{@id} is written up, as {\"path\": ..., \"heading\": ...}, or to null.")
      end

      # The action the finding keeps once decided, or nil when the decision closes it or raises it again.
      #: () -> String?
      def kept_action
        return nil unless @decision["decision"] == "still_holds"

        @decision["action"] || @finding.action
      end

      #: () -> void
      def holds
        gone unless @finding.removed_from(@members).empty?
        unkept_reason if @decision.key?("reason") && !@decision.key?("action")
      end

      # A reason on a still_holds decision that changes no action, which the record has nowhere to keep, so the fact
      # it corrects would stay as it was.
      #: () -> bot
      def unkept_reason
        invalid("still_holds keeps no reason",
                "Drop reason from #{@id}'s decision. To correct what #{@id} says, give problem, one line restating " \
                "it; to change its action, give action with the reason.")
      end

      #: (String) -> void
      def closed_or_raised(kind)
        invalid("#{kind} needs a one-line reason") if CLOSING.include?(kind) && !one_line_reason?
        invalid("raised_again needs as: the id of a new finding") if kind == "raised_again" && !raised_as_new?
      end

      #: () -> bool
      def one_line_reason? = AnswerText.new(@decision["reason"]).one_line?

      #: () -> bool
      def raised_as_new? = @new_ids.include?(@decision["as"])

      # A resolved decision may point at where its fix shows.
      #: (^(Locator) -> void) -> void
      def fix_shown(locate)
        return unless @decision.key?("evidence")

        unless @decision["decision"] == "resolved"
          invalid("only resolved may give evidence", "Drop evidence from #{@id}'s decision, or decide it resolved.")
        end
        AnswerFields.new(locate).evidence(@decision["evidence"], @place.child("evidence"))
      end

      # The decision's refusal, for a part that checks it apart: a reason and a repair, or REPAIR for nil.
      #: () -> ^(String, String?) -> void
      def refusal = ->(why, repair) { invalid(why, repair || REPAIR) }

      #: (String, ?String) -> bot
      def invalid(why, repair = REPAIR)
        raise Error.new("invalid_decision", "Prior finding #{@id}: #{why}", repair)
      end

      #: () -> bot
      def gone
        removed = @finding.removed_from(@members)
        raise Error.new("unknown_member", "Prior finding #{@id} names members no longer mapped: #{removed.join(", ")}",
                        "Decide it resolved or withdrawn with a reason, or raise it again as a new finding.")
      end
    end
  end
end

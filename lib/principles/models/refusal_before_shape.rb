# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A refusal an answer meets before its shape is checked, for a mistake the shape would refuse without naming, such
    # as a placeholder left in a field of another type. A phase lists its own, in order, and
    # SentAnswer reads each, so a new one is declared here once.
    # @interface
    module RefusalBeforeShape
      # Refuses answer, as sent from source, when it makes this mistake; nothing otherwise. shape_problems are the
      # problems its shape check finds, as Data::SchemaCheck#problems gives them, which a refusal may name beside its
      # own, so one refusal names every repair. Sorbet takes an abstract method only with a forwarding super
      # for its body, which RuboCop would otherwise call useless.
      # @abstract
      #: (untyped, String, Array[Hash[String, String]]) -> void
      def refuse_in(answer, source, shape_problems) = super # rubocop:disable Lint/UselessMethodDefinition
    end
  end
end

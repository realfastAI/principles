# typed: strict
# frozen_string_literal: true

module Principles
  # The positional words a command takes and the values the invocation gives them, after option parsing.
  class PositionalArguments
    #: (Array[String], Array[String]) -> void
    def initialize(names, values)
      @names = names.dup.freeze #: Array[String]
      @values = values.dup.freeze #: Array[String]
      freeze
    end

    #: () -> String?
    def id = %w[id id?].include?(@names.first) ? @values.first : nil

    # Every named argument other than the principle id, as the controller receives it, an optional one by its name
    # without the ?, and a last one named NAME... under NAME, holding every value from its place on, which NAME?...
    # lets be none.
    #: () -> Hash[String, untyped]
    def bindings
      bound = @names.map { it.chomp("?") }.zip(@values).to_h.except("id")
      return bound unless repeats?

      repeated = @names.last.to_s
      bound.except(repeated).merge(repeated.delete_suffix("...").chomp("?") => @values.drop(@names.length - 1))
    end

    #: () -> Array[String]
    def missing = @names.drop(@values.length).reject { |name| name.delete_suffix("...").end_with?("?") }.map(&:upcase)

    #: () -> bool
    def too_many? = !repeats? && @values.length > @names.length

    # The command's positional arguments as usage shows them, optional ones in brackets.
    #: () -> String
    def shown = @names.map { |name| name.end_with?("?") ? "[#{name.chomp("?").upcase}]" : name.upcase }.join(" ")

    private

    # Whether the last positional word, named NAME..., takes every value from its place on.
    #: () -> bool
    def repeats? = @names.last.to_s.end_with?("...")
  end
end

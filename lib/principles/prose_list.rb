# typed: strict
# frozen_string_literal: true

module Principles
  # Items as one would say them in a sentence: "a", "a and b", or "a, b and c", or with "or" for alternatives. It
  # is the one owner of that list, which several results and refusals print, so every layer may
  # load it, as it may error.rb.
  class ProseList
    #: (Array[String], ?conjunction: String) -> void
    def initialize(items, conjunction: "and")
      @items = items
      @conjunction = conjunction
      freeze
    end

    #: () -> String
    def to_s
      return @items.join if @items.length < 2

      "#{@items.take(@items.length - 1).join(", ")} #{@conjunction} #{@items.last}"
    end
  end
end

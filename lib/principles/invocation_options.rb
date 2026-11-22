# typed: strict
# frozen_string_literal: true

require "optparse"

module Principles
  # The options one invocation gives: each value or flag, and which the agent typed, which CommandLine checks
  # against what its command takes.
  class InvocationOptions
    # The options that take a value; --help, -h and --version take none.
    VALUE_OPTIONS = %w[project file description path section starting-at ending-at query role
                       check session-start commits-after hook-event as instruction].freeze #: Array[String]
    # The options that take no value, as list-member-problems --short.
    FLAG_OPTIONS = %w[short lines when-invoked always write-ups confirm open-findings history].freeze #: Array[String]
    # The options that may be given more than once, each value kept in order, as change-activation --when-files and
    # start-audit --member and --part.
    LIST_OPTIONS = %w[when-files also only member part].freeze #: Array[String]
    # The words that name an option taking the next word as its value.
    VALUE_WORDS = (VALUE_OPTIONS + LIST_OPTIONS).map { |name| "--#{name}" }.freeze #: Array[String]
    # Every word the parser reads as an option, which an option taking a value refuses as its value.
    WORDS = [*VALUE_WORDS, *FLAG_OPTIONS.map { |name| "--#{name}" }, "--help", "-h",
             "--version"].freeze #: Array[String]

    # Whether word is the name of an option that takes the next word as its value.
    #: (String) -> bool
    def self.takes_a_value?(word) = VALUE_WORDS.include?(word)

    #: () -> void
    def initialize
      @values = { "project" => Dir.pwd } #: Hash[String, untyped]
      @given = [] #: Array[String]
    end

    # Takes the options out of words, leaving the command and its positional arguments; an option no command
    # defines is refused with OptionParser::InvalidOption.
    #: (Array[String]) -> void
    def parse!(words)
      parser.parse!(words)
    end

    # An option's value, or true for a flag that was given; its name is written with underscores.
    #: (String) -> untyped
    def value(name)
      @values[name]
    end

    # Each option the agent typed, once, by its name on the command line.
    #: () -> Array[String]
    def given = @given.uniq

    # Every option's value, under its name with underscores.
    #: () -> Hash[String, untyped]
    def to_h = @values.dup

    private

    # Records that the agent typed name, and keeps its value: appended for an option that may repeat, else set.
    #: (String, untyped) -> void
    def store(name, value)
      @given << name
      key = name.tr("-", "_")
      @values[key] = LIST_OPTIONS.include?(name) ? [*@values[key], value] : value
    end

    # A parser that fills the options, and records each value or flag option the agent typed.
    #: () -> OptionParser
    def parser
      OptionParser.new do |opts|
        (VALUE_OPTIONS + FLAG_OPTIONS + LIST_OPTIONS).each do |name|
          # A flag yields true; a value option yields its value.
          opts.on(FLAG_OPTIONS.include?(name) ? "--#{name}" : "--#{name} VALUE") { |value| store(name, value) }
        end
        opts.on("--help", "-h") { @values["help"] = true }
        opts.on("--version") { @values["version"] = true }
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require "json"
require_relative "../error"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # command-steps.json, which ships in the gem beside this file and lists every command's steps.
    #
    # A run reads it without its schema. The file is part of the gem, and `rake ci` checks it against the
    # schema before every commit (spec/unit/principles/data/command_steps_file_spec.rb). So --version and
    # --help need nothing beyond the standard library, even on a Ruby where json_schemer is not installed.
    class CommandStepsFile
      PATH = File.join(__dir__, "command-steps.json").freeze #: String
      SCHEMA = File.join(__dir__, "schemas", "command-steps.schema.json").freeze #: String

      #: String
      attr_reader :path

      # path defaults to the file shipped in the gem; a spec passes a changed copy.
      #: (?String) -> void
      def initialize(path = PATH)
        @path = path
        freeze
      end

      #: () -> untyped
      def read
        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        raise Error.new("invalid_command_steps", e.message, "Repair the JSON of this file.", path)
      end

      # The file's content once it passes its schema, or a refusal naming each failing field.
      #: () -> untyped
      def read_checked
        require "json_schemer"
        require "pathname"
        data = read
        errors = JSONSchemer.schema(Pathname.new(SCHEMA)).validate(data).map { |error| error.fetch("error") }
        return data if errors.empty?

        raise Error.new("invalid_command_steps", errors.join("; "),
                        "Repair the file against schemas/command-steps.schema.json.", path)
      end
    end
  end
end

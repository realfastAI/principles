# typed: strict
# frozen_string_literal: true

require "optparse"
require_relative "command_line"

module Principles
  # The JSON object an agent reads for a failure that is not one of this tool's refusals: a usage error, a file the
  # system would not read or write, or a file of the wrong shape, each with its code and repair.
  class FailureRefusal
    # The repair for a shape error raised from this tool's own code. Such an error cannot say which file was at
    # fault, so the repair names every file a command reads, and blames none.
    SHAPE_REPAIR = "A file this command read is not in the shape this tool writes: the map in " \
                   ".principles/maps/ID.json, its audit record in .principles/audits/ID.json, or the answer given " \
                   "with --file. Compare it with git, or with the answer to fill its request printed, which " \
                   "show-open-correction ID prints for a correction."

    # executable is the invocation a usage error's repair tells the agent to run --help with.
    #: (StandardError, executable: String) -> void
    def initialize(error, executable:)
      @error = error
      @executable = executable
      freeze
    end

    # The exit status: 2 for a usage error, 1 for any other.
    #: () -> Integer
    def status = @error.is_a?(OptionParser::ParseError) ? 2 : 1

    #: () -> Hash[Symbol, String]
    def payload
      case @error
      when OptionParser::ParseError
        failure(status: "usage_error", code: "invalid_invocation", repair: usage_repair)
      when SystemCallError
        failure(status: "refused", code: "filesystem_error",
                repair: "Check the project path and file permissions, then retry.")
      else
        failure(status: "refused", code: "invalid_shape", repair: SHAPE_REPAIR)
      end
    end

    private

    # The repair a refused command line carries for the command it names, or the advice to see every command.
    #: () -> String
    def usage_repair
      error = @error
      error.is_a?(CommandLine::UsageRefusal) ? error.repair : "To see every command: #{@executable} --help"
    end

    #: (status: String, code: String, repair: String) -> Hash[Symbol, String]
    def failure(status:, code:, repair:)
      { status: status, code: code, message: @error.message, repair: repair }
    end
  end
end

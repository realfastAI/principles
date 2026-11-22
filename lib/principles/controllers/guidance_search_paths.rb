# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../views/guidance_search_paths_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # The writes to the project's recorded guidance search paths, separate from member maps and audits.
    class GuidanceSearchPaths < Command
      COMMANDS = { "add-guidance-search-path" => :adding, "remove-guidance-search-path" => :removing }
                 .freeze #: Hash[String, Symbol]

      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          operation = COMMANDS[command] or unknown(command)
          current = @project.guidance_search_paths
          updated = current.public_send(operation, options.fetch("glob"))
          unchanged = updated.same_as?(current)
          wrote = unchanged ? [] : [updated.save]
          Views::GuidanceSearchPathsResult.new(invocation)
                                          .result(status: unchanged ? "unchanged" : "guidance_search_paths_updated",
                                                  globs: updated.globs, wrote:, added: updated.added_since(current))
        end
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../views/candidate_files_result"
require_relative "../views/candidate_outlines_result"
require_relative "../views/json_with_entries_on_lines"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # list-candidate-files: the survey of the files that look like agent guidance, with their outlines within the
    # budget, and the question of which principle they carry. It changes nothing on disk, and changes for the survey's
    # reasons alone, apart from the reads of what is already mapped.
    class Survey < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          case command
          when "list-candidate-files" then list_candidate_files(options)
          when "show-candidate-outlines" then show_candidate_outlines(options.fetch("path"))
          else unknown(command)
          end
        end
      end

      private

      #: (Array[String]) -> Views::JsonWithEntriesOnLines
      def show_candidate_outlines(paths)
        found = @project.candidate_outlines(paths)
                        .within_budget { |inventory| Views::CandidateOutlinesResult.new(inventory.to_h).result.text.bytesize }
        Views::CandidateOutlinesResult.new(found.to_h).result
      end

      # The survey; with a revision, only once it names a commit in git.
      #: (Hash[String, untyped]) -> untyped
      def list_candidate_files(options)
        after = options["commits_after"]
        mapped = @principles.descriptions
        commit = @history.commit_named(after) if after
        found = @project.candidate_files(after: commit, also: options.fetch("also", []))
                        .within_budget { |inventory| candidate_files_result(inventory, mapped).text.bytesize }
        candidate_files_result(found, mapped)
      end

      # list-candidate-files' result for one inventory, as it prints.
      #: (Models::CandidateInventory, Array[Hash[String, untyped]]) -> Views::JsonWithEntriesOnLines
      def candidate_files_result(found, mapped)
        listed = Views::CandidateFilesResult::Found.new(inventory: found.to_h, untracked: found.untracked,
                                                        owner_asks: found.owner_asks)
        question = Views::CandidateFilesResult.new(invocation).question(listed, existing_maps: @principles.ids,
                                                                                map_file: @principles.file("ID"),
                                                                                mapped_principles: mapped)
        Views::JsonWithEntriesOnLines.new(question.merge("wrote" => []), under: "inventory", key: "files")
      end
    end
  end
end

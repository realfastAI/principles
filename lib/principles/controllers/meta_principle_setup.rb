# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "inventory"
require_relative "../models/entry_files"
require_relative "../models/meta_principle"
require_relative "../models/text_size"
require_relative "../views/meta_principle_result"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # Setting principles up: shows the map of the principle that keeps every other one held, and proposes its passage
    # for the agent to place with the user, since this tool writes none of the project's guidance; the
    # add-member it prints writes the map (T74). It takes no id, since the principle is the product's own.
    class MetaPrincipleSetup < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, _options)
        naming_the_executable do
          command == "show-meta-principle-passage" ? show_meta_principle_passage : unknown(command)
        end
      end

      private

      # Writes nothing: with no map, it shows the one the printed add-member creates with the passage as its first
      # member, so no memberless map waits while placement waits on an owner (T74). A map already there is shown as
      # the project holds it, since the id is its identity, and its members in an entry file are named for the agent
      # to judge whether one is the passage.
      #: () -> untyped
      def show_meta_principle_passage
        map = @principles.addable(Models::MetaPrinciple::ID)
        view = meta_principle_result
        view.proposal(printed_principle(map), placement(view), map_in_project(map),
                      existing_principles: existing_principles).merge("wrote" => [])
      end

      # map as the project holds it: whether it was there before this run, its members already in an entry file, and
      # whether principles is set up, its map having a member.
      #: (Models::Principle) -> Views::MetaPrincipleResult::MapInProject
      def map_in_project(map)
        Views::MetaPrincipleResult::MapInProject.new(
          already_mapped: @principles.mapped?(map.id), members_in_entry_files: map.members.members_in(Models::EntryFiles::PATHS),
          set_up: @principles.set_up?
        )
      end

      # The project's other principles, as list-principles lists them, which this principle's first audit keeps held.
      #: () -> Array[Hash[String, untyped]]
      def existing_principles = handed(Inventory).rows(@principles.ids - [Models::MetaPrinciple::ID])

      # Where the passage can go: how this run was started and whether the hook runs in this session, the project's
      # entry files, and the passage.
      #: (Views::MetaPrincipleResult) -> Views::MetaPrincipleResult::Placement
      def placement(view)
        runs_from = @tool.runs_from
        Views::MetaPrincipleResult::Placement.new(
          runs_from: runs_from.to_s, session_start_hook_in_this_session: runs_from.session_start_hook_in_this_session?,
          entry_files: @project.entry_files.to_a, passage: passage(view)
        )
      end

      # The view of show-meta-principle-passage's result, with how its printed commands map the passage.
      #: () -> Views::MetaPrincipleResult
      def meta_principle_result
        Views::MetaPrincipleResult.new(invocation, passage_mapping, in_git: @history.inside_git?)
      end

      # The passage member's heading and role, the role of a passage the project has that carries one of its steps,
      # and the role of any other place that keeps the principles held.
      #: () -> Views::MetaPrincipleResult::PassageMapping
      def passage_mapping
        Views::MetaPrincipleResult::PassageMapping.new(heading: Models::MetaPrinciple::PASSAGE_HEADING,
                                                       role: Models::MetaPrinciple::PASSAGE_ROLE,
                                                       step_role: Models::MetaPrinciple::STEP_ROLE,
                                                       place_role: Models::MetaPrinciple::KEEPING_PLACE_ROLE)
      end

      # The passage's text, as the agent pastes it, with its size, which loads in every session (F9), and what it
      # presumes of a teammate without principles.
      #: (Views::MetaPrincipleResult) -> Views::MetaPrincipleResult::Passage
      def passage(view)
        text = view.passage
        size = Models::TextSize.new(text)
        Views::MetaPrincipleResult::Passage.new(text: text, bytes: size.bytes, estimated_tokens: size.estimated_tokens,
                                                presumes: view.presumes(size.estimated_tokens))
      end
    end
  end
end

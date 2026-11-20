# typed: strict
# frozen_string_literal: true

require_relative "../models/command_steps"
require_relative "command"
require_relative "../views/help"
require_relative "../views/workflow_diagram"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # --help: reads every command's steps through the model and hands the help view the plain values it prints.
    class Help
      # tool is the running tool. Only the overview reads its version, which the command line reads from the build
      # or the checkout; its executable heads each command's page and starts the command it says to run next. The
      # diagram names neither.
      #: (tool: RunningTool, ?steps: Models::CommandSteps) -> void
      def initialize(tool:, steps: Models::CommandSteps.load)
        @tool = tool
        @steps = steps
      end

      #: () -> String
      def overview
        groups = @steps.groups.map do |group|
          entries = @steps.commands.select { |command| command.group == group.id }
                          .map { |command| [command.usage, command.summary] }
          [group.heading, entries]
        end
        Views::Help::Overview.new(version: @tool.version, groups: groups, executable: @tool.executable).to_s
      end

      # The page for the named command, or nil when there is no such command.
      #: (String) -> String?
      def command(name)
        command = @steps.command(name)
        return unless command

        Views::Help::CommandPage.new(usage: command.usage, prompt: command.help, writes: @steps.writes(command),
                                     steps: command.steps.map { |step| page_step(command, step) },
                                     executable: @tool.executable).to_s
      end

      # The docs page drawing every command's steps and where each leads.
      #: () -> String
      def diagram
        commands = @steps.commands.map do |command|
          nodes = command.steps.map do |step|
            Views::WorkflowDiagram::Node.new(key: key(command, step), label: step.id, agent: step.agent?)
          end
          [command.usage, nodes] #: [String, Array[Views::WorkflowDiagram::Node]]
        end
        Views::WorkflowDiagram.new(commands: commands, edges: @steps.commands.flat_map { |command| edges(command) })
                              .to_s
      end

      private

      # Each step's edges: to each branch with its condition, to the step after it, or to the first step of
      # the command the agent answers with.
      #: (Models::CommandSteps::Command) -> Array[Views::WorkflowDiagram::Edge]
      def edges(command)
        command.steps.flat_map do |step|
          inside = command.successors(step).each_with_index.map do |successor, index|
            Views::WorkflowDiagram::Edge.new(from: key(command, step), to: key(command, successor),
                                             label: step.branches[index]&.condition)
          end
          [*inside, *handover(command, step)]
        end
      end

      #: (Models::CommandSteps::Command, Models::CommandSteps::Step) -> Array[Views::WorkflowDiagram::Edge]
      def handover(command, step)
        target = step.handover.answer_with
        answered = target && @steps.command(target)
        return [] unless target && answered

        [Views::WorkflowDiagram::Edge.new(from: key(command, step), to: key(answered, answered.steps.fetch(0)),
                                          label: target, handover: true)]
      end

      # A step's Mermaid id: its command's and its own position, since step ids repeat across commands.
      #: (Models::CommandSteps::Command, Models::CommandSteps::Step) -> String
      def key(command, step)
        "c#{@steps.commands.index(command)}s#{command.steps.index(step)}"
      end

      #: (Models::CommandSteps::Command, Models::CommandSteps::Step) -> Views::Help::Step
      def page_step(command, step)
        branches = step.branches.map do |branch|
          [branch.condition, command.steps.index(command.find(branch.to)).to_i + 1] #: [String, Integer]
        end
        Views::Help::Step.new(agent: step.agent?, does: step.does, handover: page_handover(step.handover),
                              branches: branches)
      end

      #: (Models::CommandSteps::Handover) -> Views::Help::Handover
      def page_handover(handover)
        target = handover.answer_with
        Views::Help::Handover.new(checks: handover.checks, cannot_check: handover.cannot_check,
                                  then_run: handover.answer_usage || (target && @steps.command(target)&.usage),
                                  then_run_when: handover.answer_when)
      end
    end
  end
end

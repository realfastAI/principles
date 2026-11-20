# typed: strict
# frozen_string_literal: true

require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What --help prints: Markdown, because it is a prompt the agent reads before running a command. It is kept short,
    # since every line lands in the agent's context. Refusal codes stay out: a refusal arrives with its own code and
    # repair when it happens.
    module Help
      # What the page says after an agent's step: what the tool then checks, what it cannot check, and the
      # usage of the command the agent runs next.
      class Handover
        #: String?
        attr_reader :checks
        #: String?
        attr_reader :cannot_check
        #: String?
        attr_reader :then_run
        # When the agent runs then_run, where it is the agent's to time; "Then" otherwise.
        #: String?
        attr_reader :then_run_when

        #: (?checks: String?, ?cannot_check: String?, ?then_run: String?, ?then_run_when: String?) -> void
        def initialize(checks: nil, cannot_check: nil, then_run: nil, then_run_when: nil)
          @checks = checks
          @cannot_check = cannot_check
          @then_run = then_run
          @then_run_when = then_run_when
          freeze
        end

        # The command to run next ends its line, with no backticks, so it pastes as it stands.
        #: (String) -> Array[String]
        def lines(executable)
          [("The tool then checks that #{checks}" if checks), ("It cannot check #{cannot_check}" if cannot_check),
           ("#{then_run_when ? "#{then_run_when}, run" : "Then run"}: #{executable} #{then_run}" if then_run)].compact
        end
      end

      # One numbered step as the page prints it: whose step it is, what it does, what follows an agent's
      # step, and each branch's condition with the number of the step it leads to.
      class Step
        #: bool
        attr_reader :agent
        #: String
        attr_reader :does
        #: Handover
        attr_reader :handover
        #: Array[[String, Integer]]
        attr_reader :branches

        #: (agent: bool, does: String, ?handover: Handover, ?branches: Array[[String, Integer]]) -> void
        def initialize(agent:, does:, handover: Handover.new, branches: [])
          @agent = agent
          @does = does
          @handover = handover
          @branches = branches.freeze #: Array[[String, Integer]]
          freeze
        end
      end

      # The overview: what the tool is, each group's heading with its commands' usage and summary, and how
      # the commands chain, with each command it prints started by the running executable.
      class Overview
        #: (version: String, groups: Array[[String, Array[[String, String]]]], executable: String) -> void
        def initialize(version:, groups:, executable:)
          @version = version
          @groups = groups
          @executable = executable
          freeze
        end

        #: () -> String
        def to_s
          commands = @groups.map do |heading, entries|
            "## #{heading}\n\n#{entries.map { |usage, summary| "- `#{usage}`: #{summary}" }.join("\n")}"
          end
          Prompts.markdown("learn-what-a-command-does/every-command-and-how-they-chain",
                           version: @version, commands: commands.join("\n\n"), executable: @executable,
                           project_selection: Prompts.text("learn-what-a-command-does/select-the-project-root"))
        end
      end

      # One command's page, headed by the command as the running executable takes it: its prose prompt, what it
      # writes, then its numbered steps.
      class CommandPage
        #: (usage: String, prompt: String, writes: String, steps: Array[Step], executable: String) -> void
        def initialize(usage:, prompt:, writes:, steps:, executable:)
          @usage = usage
          @executable = executable
          @prompt = prompt
          @writes = writes
          @steps = steps
          freeze
        end

        #: () -> String
        def to_s
          numbered = @steps.each_with_index.map { |step, index| "#{index + 1}. #{step_text(step)}" }
          ["# #{@executable} #{@usage}", Prompts.markdown(@prompt, executable: @executable), @writes, "## Steps",
           numbered.join("\n"), "A step that fails prints a refusal with its code and a repair.",
           Prompts.text("learn-what-a-command-does/select-the-project-root")].join("\n\n")
        end

        private

        #: (Step) -> String
        def step_text(step)
          branches = step.branches.map { |condition, number| "If #{condition}: step #{number}." }
          [step.agent ? "**You:** #{step.does}" : "The tool: #{step.does}", *step.handover.lines(@executable),
           *branches]
            .join("\n   ")
        end
      end
    end
  end
end

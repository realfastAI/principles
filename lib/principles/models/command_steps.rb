# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../data/command_steps_file"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The steps each command runs: which are this tool's and which are the agent's, the refusals each of
    # this tool's steps can raise, and where each step leads. Each command's --help and the workflow diagram
    # are drawn from it. It is built from data Data::CommandStepsFile has already checked
    # against its schema, and checks what a schema cannot: every step a branch names exists, every refusal
    # group exists, and every command a step hands over to is real. The prompts it names are checked by
    # spec/unit/principles/views/prompts_spec.rb, because the domain reads no files.
    class CommandSteps
      # Where a step leads when it branches.
      class Branch
        #: String
        attr_reader :to
        #: String
        attr_reader :condition

        # A step's branches, from its "next" list.
        #: (Array[Hash[String, String]]) -> Array[Branch]
        def self.all(edges)
          edges.map { |edge| new(edge.fetch("to"), edge.fetch("when")) }.freeze
        end

        #: (String, String) -> void
        def initialize(to, condition)
          @to = to
          @condition = condition
          freeze
        end
      end

      # What an agent's step hands back: what this tool then checks, what it cannot, and the command the agent
      # answers with.
      class Handover
        #: String?
        attr_reader :checks
        #: String?
        attr_reader :cannot_check
        #: String?
        attr_reader :answer_with
        # When the agent runs answer_with, where that is the agent's to time, as a first full audit is.
        #: String?
        attr_reader :answer_when
        # The form of answer_with the step hands to, where its whole usage would mislead, as a first full audit
        # that --member would make a refused one-member audit.
        #: String?
        attr_reader :answer_usage

        #: (Hash[String, untyped]) -> void
        def initialize(data)
          @checks = data["checks"] #: String?
          @cannot_check = data["cannot_check"] #: String?
          @answer_with = data["answer_with"] #: String?
          @answer_when = data["answer_when"] #: String?
          @answer_usage = data["answer_usage"] #: String?
          freeze
        end

        # Whether answer_usage, if given, is a form of the command answer_with names, so it cannot drift to another.
        #: () -> bool
        def usage_names_its_command?
          usage = @answer_usage
          usage.nil? || usage == @answer_with || usage.start_with?("#{@answer_with} ")
        end
      end

      # One step: this tool's ("cli") or the agent's ("agent").
      class Step
        #: String
        attr_reader :id
        #: String
        attr_reader :does
        #: Array[String]
        attr_reader :refusals
        #: String?
        attr_reader :prompt
        #: Handover
        attr_reader :handover
        #: Array[Branch]
        attr_reader :branches

        #: (Hash[String, untyped], Array[String]) -> void
        def initialize(data, refusals)
          @id = data.fetch("id") #: String
          @agent = data.fetch("actor") == "agent" #: bool
          @does = data.fetch("does") #: String
          @refusals = refusals.freeze #: Array[String]
          @prompt = data["prompt"] #: String?
          @handover = Handover.new(data) #: Handover
          @branches = Branch.all(data.fetch("next", [])) #: Array[Branch]
          freeze
        end

        #: () -> bool
        def agent?
          @agent
        end
      end

      # A heading the overview lists commands under, and what every command under it writes.
      class Group
        #: String
        attr_reader :id
        #: String
        attr_reader :heading
        #: String
        attr_reader :writes

        #: (Hash[String, untyped]) -> void
        def initialize(data)
          @id = data.fetch("id") #: String
          @heading = data.fetch("heading") #: String
          @writes = data.fetch("writes") #: String
          freeze
        end
      end

      # One command, with its steps in the order they run.
      class Command
        #: String
        attr_reader :name
        #: String
        attr_reader :usage
        #: String
        attr_reader :group
        # The named options it takes, without their dashes, besides --project and --help.
        #: Array[String]
        attr_reader :options
        # The named options it cannot run without, which the command line refuses together with any missing argument.
        #: Array[String]
        attr_reader :requires
        #: String
        attr_reader :summary
        #: String
        attr_reader :help
        #: Array[Step]
        attr_reader :steps

        #: (Hash[String, untyped], Array[Step]) -> void
        def initialize(data, steps)
          @name = data.fetch("name") #: String
          @usage = data.fetch("usage") #: String
          @group = data.fetch("group") #: String
          @options = data.fetch("options").freeze #: Array[String]
          @requires = data.fetch("requires", []).freeze #: Array[String]
          @summary = data.fetch("summary") #: String
          @help = data.fetch("help") #: String
          @steps = steps.freeze #: Array[Step]
          freeze
        end

        # The steps a step leads to: its branches, or else the next step unless it hands over to a command.
        #: (Step) -> Array[Step]
        def successors(step)
          return step.branches.map { |branch| find(branch.to) } if step.branches.any?
          return [] if step.handover.answer_with

          following = @steps[@steps.index(step).to_i + 1]
          following ? [following] : []
        end

        # The first rule of its own entry the command breaks, or nil when it keeps them all.
        #: () -> String?
        def fault
          ids = @steps.map(&:id)
          return "#{@name} repeats a step id" unless ids.uniq == ids

          # The command line refuses an option a command does not take, so it could never be given.
          untaken = @requires - @options
          "#{@name} requires #{untaken.join(", ")}, which it does not take" if untaken.any?
        end

        #: (String) -> Step
        def find(id)
          @steps.find { |step| step.id == id } || raise(KeyError, "#{@name} has no step #{id}")
        end
      end

      # The overview's headings, in the order it lists them.
      #: Array[Group]
      attr_reader :groups
      #: Array[String]
      attr_reader :every_command_refuses
      #: Array[Command]
      attr_reader :commands

      # Every command's steps, read from the command-steps.json the gem ships.
      #: () -> CommandSteps
      def self.load
        new(Data::CommandStepsFile.new.read, Data::CommandStepsFile::PATH)
      end

      # data is the validated content of command-steps.json; source names it in a refusal.
      #: (untyped, String) -> void
      def initialize(data, source)
        @source = source
        @groups = data.fetch("groups").map { |group| Group.new(group) }.freeze #: Array[Group]
        @refusal_groups = data.fetch("refusal_groups") #: Hash[String, Array[String]]
        @every_command_refuses = @refusal_groups.fetch("any-command") #: Array[String]
        @commands = data.fetch("commands").map { |command| build(command) }.freeze #: Array[Command]
        check_references
        freeze
      end

      #: (String) -> Command?
      def command(name)
        @commands.find { |command| command.name == name }
      end

      # What a command writes, which every command in its group shares.
      #: (Command) -> String
      def writes(command)
        @groups.find { |group| group.id == command.group }&.writes || refuse("#{command.name} is in no group")
      end

      # Every refusal code some step, or every command, can raise.
      #: () -> Array[String]
      def refusal_codes
        (@every_command_refuses + @commands.flat_map { |command| command.steps.flat_map(&:refusals) }).uniq.sort
      end

      # Every prompt this file names: each command's help and each step's prompt.
      #: () -> Array[String]
      def prompt_names
        @commands.flat_map { |command| [command.help, *command.steps.filter_map(&:prompt)] }.uniq.sort
      end

      private

      #: (Hash[String, untyped]) -> Command
      def build(data)
        steps = data.fetch("steps").map do |step|
          Step.new(step, (step.fetch("refuses", []) + step.fetch("refuses_like", []).flat_map do |group|
            refusal_group(group)
          end).uniq)
        end
        Command.new(data, steps)
      end

      #: (String) -> Array[String]
      def refusal_group(name)
        @refusal_groups.fetch(name) { refuse("No refusal group #{name}") }
      end

      #: () -> void
      def check_references
        names = @commands.map(&:name)
        refuse("Command names repeat") unless names.uniq == names
        @commands.each { |command| check_command(command, names) }
      end

      #: (Command, Array[String]) -> void
      def check_command(command, names)
        writes(command)
        fault = command.fault
        refuse(fault) if fault
        ids = command.steps.map(&:id)
        command.steps.each { |step| check_step("#{command.name}/#{step.id}", step, names, ids) }
      end

      #: (String, Step, Array[String], Array[String]) -> void
      def check_step(where, step, names, ids)
        target = step.handover.answer_with
        refuse("#{where} answers with unknown command #{target}") if target && !names.include?(target)
        unless step.handover.usage_names_its_command?
          refuse("#{where}'s handover form #{step.handover.answer_usage} does not name #{target}")
        end
        unknown = step.branches.map(&:to) - ids
        refuse("#{where} branches to unknown step #{unknown.join(", ")}") if unknown.any?
      end

      #: (String) -> bot
      def refuse(message)
        raise Error.new("invalid_command_steps", message,
                        "Repair the file so every step it names exists.", @source)
      end
    end
  end
end

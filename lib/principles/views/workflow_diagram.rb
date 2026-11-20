# typed: strict
# frozen_string_literal: true

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The docs page that draws every command's steps as one Mermaid flowchart: a subgraph
    # per command, this tool's steps as boxes, the agent's as rounded shapes, and a dashed edge where the agent
    # hands over to the command it answers with. It is generated, and a spec fails when the committed copy is
    # stale, so the drawing cannot drift from the steps --help prints.
    class WorkflowDiagram
      # One step, keyed by an id that is safe in Mermaid.
      class Node
        #: String
        attr_reader :key
        #: String
        attr_reader :label
        #: bool
        attr_reader :agent

        #: (key: String, label: String, agent: bool) -> void
        def initialize(key:, label:, agent:)
          @key = key
          @label = label
          @agent = agent
          freeze
        end

        #: () -> String
        def to_s
          agent ? "#{key}([\"#{label}\"])" : "#{key}[\"#{label}\"]"
        end
      end

      # Where one step leads: a branch's condition, if any, and whether the agent hands over to another command.
      class Edge
        #: (from: String, to: String, ?label: String?, ?handover: bool) -> void
        def initialize(from:, to:, label: nil, handover: false)
          @from = from
          @to = to
          @label = label
          @handover = handover
          freeze
        end

        #: () -> String
        def to_s
          "#{@from} #{@handover ? "-.->" : "-->"}#{"|\"#{@label}\"|" if @label} #{@to}"
        end
      end

      INTRODUCTION = <<~MARKDOWN
        # principles command workflow diagram

        Generated from `lib/principles/data/command-steps.json` by `bundle exec rake diagram`; do not edit it by hand.
        Each box is a step the principles command runs and each rounded shape is the agent's. A dashed arrow is the
        agent running the command it answers with. Each command's `--help` prints the same steps in words.
      MARKDOWN

      #: (commands: Array[[String, Array[Node]]], edges: Array[Edge]) -> void
      def initialize(commands:, edges:)
        @commands = commands
        @edges = edges
        freeze
      end

      #: () -> String
      def to_s
        subgraphs = @commands.each_with_index.map do |(usage, nodes), index|
          ["  subgraph c#{index}[\"#{usage}\"]", *nodes.map { |node| "    #{node}" }, "  end"]
        end
        lines = ["flowchart TD", *subgraphs.flatten, *@edges.map { |edge| "  #{edge}" }]
        "#{INTRODUCTION}\n```mermaid\n#{lines.join("\n")}\n```\n"
      end
    end
  end
end

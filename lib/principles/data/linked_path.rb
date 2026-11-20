# typed: strict
# frozen_string_literal: true

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # A path in the project, as its symbolic links lead it. A host may load an instruction file through a link, and
    # git holds a link as the name of its target, so the text at path depends on every link on the way, a linked
    # folder's included, and on the file they lead to.
    class LinkedPath
      # The most links followed, as an operating system caps them, so a cycle ends.
      MOST_LINKS = 40

      # One link on the way to a path: where it is, the target it names, and the parts of the path beyond it.
      class Hop
        #: String
        attr_reader :link, :target

        #: Array[String]
        attr_reader :rest

        #: (String, String, Array[String]) -> void
        def initialize(link, target, rest)
          @link = link
          @target = target
          @rest = rest
          freeze
        end
      end

      # read_link gives the target the link at a path relative to root names, as the disk holds it, or nil for a
      # path that is not a link.
      #: (path: String, root: String, read_link: ^(String) -> String?) -> void
      def initialize(path:, root:, read_link:)
        @path = path
        @root = root
        @read_link = read_link
        freeze
      end

      # The paths, relative to root, that the text at path depends on: each link on the way, in order, then the file
      # they lead to. A path with no link gives itself. So does one whose links leave the project or never end, which
      # reading it refuses.
      #: () -> Array[String]
      def text_paths
        links = [] #: Array[String]
        current = @path #: String
        MOST_LINKS.times do
          hop = first_link(current) or return [*links, current]
          links << hop.link
          followed = followed(hop) or return [@path]
          current = followed
        end
        [@path]
      end

      # The file the links lead to, the last of text_paths: path itself when it passes through no link.
      #: () -> String
      def leads_to = text_paths.fetch(-1)

      private

      # The first link on the way to path; nil when there is none.
      #: (String) -> Hop?
      def first_link(path)
        parts = path.split("/")
        (1..parts.length).each do |count|
          link = parts.take(count).join("/")
          target = @read_link.call(link) or next
          return Hop.new(link, target, parts.drop(count))
        end
        nil
      end

      # The path the hop's target and the parts beyond it name, relative to root; nil when it leaves the project.
      #: (Hop) -> String?
      def followed(hop)
        target = hop.target
        if target.start_with?("/")
          return unless target.start_with?("#{@root}/")

          return [target.delete_prefix("#{@root}/"), *hop.rest].join("/")
        end
        normal([*hop.link.split("/")[0...-1], *target.split("/"), *hop.rest])
      end

      # parts joined, with each "." dropped and each ".." taking away the part before it; nil when one has none to
      # take, so the path would leave the project.
      #: (Array[String]) -> String?
      def normal(parts)
        kept = [] #: Array[String]
        parts.each do |part|
          next if part.empty? || part == "."
          return nil if part == ".." && kept.empty?

          part == ".." ? kept.pop : kept.push(part)
        end
        kept.join("/")
      end
    end
  end
end

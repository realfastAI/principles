# typed: strict
# frozen_string_literal: true

require_relative "../data/request_logging_folder"
require_relative "../error"
require_relative "carrier_kind"
require_relative "member"
require_relative "member_text_as_sent"
require_relative "misspelt_member_id"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # Which mapped members' text the captured requests hold. Each member is measured by its lines long enough to be
    # told apart from common text, its leading indentation stripped since a host may re-indent; rg finds the decoded
    # request lines holding one, and each member is reported by where its lines were seen.
    class MembersInLoggedRequests
      # A line shorter than this, in bytes, is too common to say a member reached a request.
      SHORTEST_LINE = 24
      # The folder a request names when the agent read or named a captured request in it, so what is found there may
      # be a quote of an earlier request rather than what the host loaded. rg finds lines holding it; only one naming a
      # request file in it counts, since a member may document the folder itself.
      QUOTED = "#{Data::RequestLoggingFolder::FOLDER}/#{Data::RequestLoggingFolder::REQUESTS}/".freeze #: String
      QUOTING = /#{Regexp.escape(QUOTED)}\S*\.request\.json/
      # Each status a member can have, in the order a count of them prints.
      STATUSES = %w[present present_but_not_loaded absent not_a_carrier unmeasurable].freeze #: Array[String]

      # One mapped member: its principle, its key, the member as its map holds it now, the lines it is measured by,
      # and the kind of carrier its file is.
      class Measured
        #: String
        attr_reader :principle, :member

        #: Array[String]
        attr_reader :lines

        #: (principle: String, member: String, mapped: Member, text: String, carrier: CarrierKind) -> void
        def initialize(principle:, member:, mapped:, text:, carrier:)
          @principle = principle
          @member = member
          @mapped = mapped
          @lines = text.lines.map(&:strip).select { it.bytesize >= SHORTEST_LINE }.uniq.freeze #: Array[String]
          @carrier = carrier
          freeze
        end

        # Its status, given where it was seen and the tools whose loading the host deferred, each as [request, path]:
        # unmeasurable when it has no line to look for; present once seen in a place the model reads; present but not
        # loaded when seen only inside a deferred tool; else absent, or not a carrier when no host loads its file by
        # itself, since its absence is then expected.
        #: (Array[Hash[String, untyped]], Array[[String, String]]) -> String
        def status(seen, deferred)
          return "unmeasurable" if @lines.empty?
          return @carrier.carrier? ? "absent" : "not_a_carrier" if seen.empty?

          seen.all? { inside_any?(it, deferred) } ? "present_but_not_loaded" : "present"
        end

        # Where its lines were seen among matches, each place a request, path and segment, with the share of its lines
        # there, the bytes of every occurrence of them, how many occurrences there are, and the byte offset of each in
        # its string. holding gives the patterns each matched line holds.
        #: (Array[Data::KeptLine], Hash[String, String?], Hash[String, Array[String]])
        #|   -> Array[Hash[String, untyped]]
        def seen(matches, sources, holding)
          found = matches.group_by(&:place)
                         .transform_values { occurrences(it, holding) }
          found.reject { |_, occurring| occurring.empty? }.map do |(request, path, segment), occurring|
            { "request" => request, "query_source" => sources[request], "path" => path, "segment" => segment,
              **measures(occurring) }
          end
        end

        # Its id, where it is now.
        #: () -> String
        def id = @mapped.id

        # Whether it has no line long enough to be told apart from common text, so no logged request can show it.
        #: () -> bool
        def too_short? = @lines.empty?

        # The move-member options that widen it, with placeholders to fill, as Member gives them.
        #: () -> String
        def move_placeholders = @mapped.move_placeholders

        private

        # Whether place, one of where it was seen, lies inside one of tools.
        #: (Hash[String, untyped], Array[[String, String]]) -> bool
        def inside_any?(place, tools)
          tools.any? do |request, path|
            place["request"] == request && (place["path"] == path || place["path"].to_s.start_with?("#{path}."))
          end
        end

        # What occurring, the occurrences of its lines in one place as [line, offset], measure there: the share of its
        # lines they are, their bytes, each occurrence counted, how many there are, and where each starts.
        #: (Array[[String, Integer]]) -> Hash[String, untyped]
        def measures(occurring)
          { "share" => occurring.map(&:first).uniq.size.fdiv(@lines.size),
            "bytes" => occurring.sum { |line, _| line.bytesize }, "count" => occurring.size,
            "offsets" => occurring.map(&:last).sort }
        end

        # Each occurrence of its lines in matches, as [line, offset], offset the byte in its string the occurrence
        # starts at. holding gives the patterns each matched line holds, so only those are looked for in it.
        #: (Array[Data::KeptLine], Hash[String, Array[String]]) -> Array[[String, Integer]]
        def occurrences(matches, holding)
          matches.flat_map do |kept|
            text = kept.text
            (@lines & holding.fetch(text, [])).flat_map { |line| starts(text, line).map { [line, kept.offset + it] } }
          end
        end

        # The byte offset of each occurrence of line in text, each found after the one before it ends.
        #: (String, String) -> Array[Integer]
        def starts(text, line)
          found = [] #: Array[Integer]
          from = 0
          while (start = text.byteindex(line, from))
            found << start
            from = start + line.bytesize
          end
          found
        end
      end

      # Every mapped member of project, by principle, with its text now.
      #: (Project) -> MembersInLoggedRequests
      def self.mapped_in(project)
        principles = project.principles
        new(principles.ids.flat_map { |id| measured(project, id, principles.find(id).members, &:key) })
      end

      # Every member of project's own files, not a plugin's, whose text has no line long enough to be told apart from
      # common text, so no logged request can show whether it reached the agent; the project widens it with
      # move-member.
      #: (Project) -> Array[Measured]
      def self.too_short_in(project)
        principles = project.principles
        principles.ids.flat_map { |id| measured(project, id, principles.find(id).members.in_project, &:key) }
                  .select(&:too_short?)
      end

      # The members of map whose ids are in listed, each named by its id as the audit's request lists it.
      #: (Project, Principle, Array[String]) -> MembersInLoggedRequests
      def self.listed_in(project, map, listed)
        new(measured(project, map.id, map.members, &:id).select { listed.include?(it.member) })
      end

      # Each of members of the principle, named as name gives, with its text now as a host sends it and the kind of
      # carrier it is.
      #: (Project, String, PrincipleMembers) { (Member) -> String } -> Array[Measured]
      def self.measured(project, principle, members, &name)
        loads = project.member_loads(members)
        members.map do |member|
          Measured.new(principle:, member: name.call(member), mapped: member,
                       text: MemberTextAsSent.of(project, member.locator).to_s,
                       carrier: loads.fetch(member.id).carrier_kind)
        end
      end
      private_class_method :measured

      #: (Array[Measured]) -> void
      def initialize(members)
        @members = members
        freeze
      end

      # Only the members whose keys are named, so the scan looks for their lines alone; refused as unknown_member for
      # a key no member has, naming the key it is spelled like, since a misspelt one would list nothing.
      #: (Array[String]) -> MembersInLoggedRequests
      def only(keys)
        known = @members.map(&:member)
        unknown = keys.find { !known.include?(it) }
        raise unknown_member(unknown, known) if unknown

        self.class.new(@members.select { keys.include?(it.member) })
      end

      # Every line a member is measured by, once each, and the logged request's path a quoting request holds, for
      # the scan to find.
      #: () -> Array[String]
      def patterns = [*@members.flat_map(&:lines), QUOTED].uniq

      # How many members have each status, every status counted, then each member with where it was seen, given the
      # scan's requests, its matches and the tools it found deferred, how many requests the index gives no
      # query_source, and which requests quote a logged request's path.
      #: (Array[Hash[String, String?]], Array[Data::KeptLine], Array[[String, String]])
      #|   -> { members_by_status: Hash[String, Integer], members: Array[Hash[String, untyped]], orphans: Integer,
      #|        quoting_requests: Array[String] }
      def report(requests, matches, deferred)
        members = members_seen(requests, matches, deferred)
        { members_by_status: by_status(members), members: members, orphans: requests.count { it["query_source"].nil? },
          quoting_requests: matches.select { QUOTING.match?(it.text) }.map(&:request).uniq.sort }
      end

      private

      # The refusal for key, which no mapped member has, with the one it is spelled like, if any.
      #: (String, Array[String]) -> Error
      def unknown_member(key, known)
        unknown = "#{key} is not a mapped member's key"
        repair = "Run show-members-in-logged-requests without --member to list every member's key."
        closest = MisspeltMemberId.new(key).closest(known)
        return Error.new("unknown_member", unknown, repair) unless closest

        Error.new("unknown_member", "#{unknown}; did you mean #{closest}?", repair).including("did_you_mean" => closest)
      end

      # How many of members, as report lists them, have each status, none left out for having no member.
      #: (Array[Hash[String, untyped]]) -> Hash[String, Integer]
      def by_status(members) = STATUSES.to_h { |status| [status, members.count { it.fetch("status") == status }] }

      #: (Array[Hash[String, String?]], Array[Data::KeptLine], Array[[String, String]])
      #|   -> Array[Hash[String, untyped]]
      def members_seen(requests, matches, deferred)
        sources = requests.to_h { [it.fetch("file").to_s, it["query_source"]] }
        holding = patterns_held(matches)
        @members.map do |member|
          seen = member.seen(matches, sources, holding)
          { "principle" => member.principle, "member" => member.member, **moved_to(member),
            "status" => member.status(seen, deferred), "seen" => seen }
        end
      end

      # Where member is now, as its id, once a move has left its key naming where it was; nothing while they agree.
      #: (Measured) -> Hash[String, String]
      def moved_to(member) = member.id == member.member ? {} : { "id" => member.id }

      # The patterns each distinct matched line holds. rg names only the leftmost match on a line, so two members
      # sharing a line are both found here. The same member text recurs in every request, so the distinct lines rg
      # matched are few, and this pass over them is bounded by that small set, not by the bodies' size.
      #: (Array[Data::KeptLine]) -> Hash[String, Array[String]]
      def patterns_held(matches)
        all = patterns
        matches.map(&:text).uniq.to_h { |line| [line, all.select { line.include?(it) }] }
      end
    end
  end
end

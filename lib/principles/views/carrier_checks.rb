# typed: strict
# frozen_string_literal: true

require_relative "carrier_practices_page"
require_relative "invocation"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The checks a request prints where the agent judges or edits members: one for each carrier kind the members are
    # in, once, with the ids of the members it is for and its page's size, then once for them all the command that
    # prints a kind's page, which differs between kinds only in its last word.
    class CarrierChecks
      # kinds is each member's carrier kind by its id, in the order the request lists the members.
      #: (Hash[String, String], Invocation) -> void
      def initialize(kinds, invocation)
        @kinds = kinds
        @invocation = invocation
        freeze
      end

      # One check per kind, in the order its first member is listed, and the page command; nothing for no members.
      #: () -> Hash[String, untyped]
      def to_h
        return {} if @kinds.empty?

        { "checks" => @kinds.group_by { _2 }.map { |kind, members| check(kind, members.map(&:first)) },
          "page_command" => @invocation.in_project("show-carrier-practices", usage: "CARRIER") }
      end

      private

      #: (String, Array[String]) -> Hash[String, untyped]
      def check(kind, member_ids)
        page = CarrierPracticesPage.of(kind)
        { "carrier" => kind, "member_ids" => member_ids, "check" => page.check, "page_bytes" => page.body.bytesize }
      end
    end
  end
end

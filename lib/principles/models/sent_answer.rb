# typed: strict
# frozen_string_literal: true

require_relative "../data/schema_check"
require_relative "../data/project_files"
require_relative "../error"
require_relative "refusal_before_shape"
require_relative "request_id"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # An answer an agent sent for a phase's request, read from its source, whose head, the fields every answer hands
    # back as its request printed them, is checked on arrival: they say whether it still answers that request.
    # The rest is checked only once that request is known, against the placeholders its template printed and
    # the phase's schema.
    class SentAnswer
      HEAD = %w[request_id basis].freeze #: Array[String]

      # What a refusal's message calls the answer: the agent holds its file's path, which cost context in every
      # repair.
      NAMED = "The answer" #: String
      # What a refusal to read its file calls that file.
      FILE_NAMED = "The answer file" #: String

      # The repair of a field-by-field refusal for the acknowledgements phase, whose controller refuses its own
      # fields: the agent repairs the bare answer it saved and fills, which --as template prints.
      REPAIR = "Repair each field listed in the answer you saved from start-audit with the same --member options " \
               "and --as template." #: String

      # The answer read from the file or stdin the agent named, to the request given, the REQUEST_ID the agent typed,
      # or when it typed none the request_id the answer names, as its template printed it, using that request's
      # phase's schema.
      #: (Data::ProjectFiles, String, stdin: String?, given: String?) -> SentAnswer
      def self.read(files, file, stdin:, given:)
        parsed = if file == "-" then files.parse_json(stdin.to_s, "-", named: NAMED)
                 else files.read_json(file, named: FILE_NAMED)
                 end
        new(parsed, file, RequestId.parse(given || named_request(parsed)))
      end

      # The request_id the answer names, refused when it names none, since no REQUEST_ID was typed either.
      #: (untyped) -> String
      def self.named_request(parsed)
        named = parsed["request_id"] if parsed.is_a?(Hash)
        return named if named.is_a?(String)

        raise Error.new("unknown_request", "#{NAMED} names no request_id, and no REQUEST_ID was given",
                        "Keep in the answer the request_id its template printed, or give it as REQUEST_ID.")
      end
      private_class_method :named_request

      #: RequestId
      attr_reader :request_id

      # parsed is the answer as its source, a file or - for stdin, holds it, to request_id, whose phase's answer schema
      # it is checked against.
      #: (untyped, String, RequestId) -> void
      def initialize(parsed, source, request_id)
        @parsed = parsed
        @source = source
        @request_id = request_id
        @check = Data::SchemaCheck.new("#{request_id.phase}-answer") #: Data::SchemaCheck
        @repair = "Repair each field listed, starting from #{request_id.answer_to_fill}." #: String
        @check.only(HEAD).checked(parsed, code: "invalid_answer", source: source, repair: @repair, named: NAMED)
        freeze
      end

      # The answer's head, checked.
      #: () -> Hash[String, untyped]
      def head = @parsed.slice(*HEAD)

      # The whole answer, once each refusal its request's rules make before its shape, in order, then its shape, is
      # checked: such as a stray check_result on a member with no check, a field holding a placeholder its
      # request's template did not print, and a one-member audit's field left as its template printed it, each handed
      # the shape's problems to name beside its own.
      #: (Array[RefusalBeforeShape]) -> untyped
      def checked(before_shape)
        shape_problems = @check.problems(@parsed)
        before_shape.each { |refusal| refusal.refuse_in(@parsed, @source, shape_problems) }
        @check.checked(@parsed, code: "invalid_answer", source: @source, repair: @repair, named: NAMED)
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The fields a schema names, kept from data at every depth. This tool's schemas allow fields they do not
    # name, so an older version can read a newer file, but a field a person or agent added must never
    # be printed back as if this tool had said it.
    class KnownFields
      #: (Hash[String, untyped]) -> void
      def initialize(schema)
        @schema = schema
        freeze
      end

      # data with only the named fields; data is assumed to fit the schema.
      #: (untyped, ?Hash[String, untyped]) -> untyped
      def of(data, schema = @schema)
        case data
        when Hash then named(data, schema)
        when Array then schema["items"] ? data.map { |each| of(each, schema.fetch("items")) } : data
        else data
        end
      end

      private

      # An object's named fields, and every field when the schema gives one schema for all its values.
      #: (Hash[String, untyped], Hash[String, untyped]) -> Hash[String, untyped]
      def named(data, schema)
        properties = schema.fetch("properties", {})
        each_value = schema["additionalProperties"]
        data.each_with_object({}) do |(key, value), kept|
          if properties.key?(key) then kept[key] = of(value, properties.fetch(key))
          elsif each_value.is_a?(Hash) then kept[key] = of(value, each_value)
          end
        end
      end
    end
  end
end

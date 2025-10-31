# frozen_string_literal: true

module MLC
  module Diagnostics
    class EventLogger
      DEFAULT_EVENTS = %i[
        stdlib_function_imported
        stdlib_type_imported
        stdlib_missing_item
        type_mismatch
        cpp_function_rule_applied
        cpp_function_lowered
      ].freeze

      def self.attach(bus, io: $stderr, events: DEFAULT_EVENTS)
        events.each do |event|
          bus.subscribe(event) do |payload|
            io.puts(format_message(event, payload))
          end
        end
      end

      def self.format_message(event, payload)
        details = payload&.map { |key, value| "#{key}=#{value.inspect}" }&.join(" ")
        details && !details.empty? ? "[#{event}] #{details}" : "[#{event}]"
      end
    end
  end
end

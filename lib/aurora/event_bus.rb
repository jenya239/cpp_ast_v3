# frozen_string_literal: true

module Aurora
  class EventBus
    def initialize
      @handlers = Hash.new { |hash, key| hash[key] = [] }
    end

    def subscribe(event, callable = nil, &block)
      handler = callable || block
      raise ArgumentError, "Provide a callable or block" unless handler

      @handlers[event.to_sym] << handler
    end

    def publish(event, payload = {})
      @handlers[event.to_sym].each do |handler|
        handler.call(payload)
      end
    end
  end
end

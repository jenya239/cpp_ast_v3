# frozen_string_literal: true

require_relative "../test_helper"

class EventBusTest < Minitest::Test
  def test_publish_notifies_subscribers
    bus = MLC::EventBus.new
    payloads = []
    bus.subscribe(:demo) { |payload| payloads << payload }

    bus.publish(:demo, value: 1)
    bus.publish(:demo, value: 2)

    assert_equal [{value: 1}, {value: 2}], payloads
  end

  def test_subscribe_with_callable
    bus = MLC::EventBus.new
    collector = Class.new do
      attr_reader :payloads
      def initialize
        @payloads = []
      end
      def call(payload)
        @payloads << payload
      end
    end.new

    bus.subscribe(:demo, collector)
    bus.publish(:demo, foo: :bar)

    assert_equal [{foo: :bar}], collector.payloads
  end

  def test_no_handler_raises
    bus = MLC::EventBus.new
    assert_raises(ArgumentError) { bus.subscribe(:demo) }
  end
end

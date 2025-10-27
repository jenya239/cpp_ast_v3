# frozen_string_literal: true

require_relative "../../test_helper"
require "stringio"

class EventLoggerTest < Minitest::Test
  def test_logs_payload_to_io
    bus = Aurora::EventBus.new
    io = StringIO.new

    Aurora::Diagnostics::EventLogger.attach(bus, io: io, events: [:custom])
    bus.publish(:custom, foo: 42)

    io.rewind
    assert_match(/\[custom\]/, io.read)
  end
end

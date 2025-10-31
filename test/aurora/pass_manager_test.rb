# frozen_string_literal: true

require_relative "../test_helper"

class PassManagerTest < Minitest::Test
  def test_runs_passes_in_order
    manager = Aurora::PassManager.new
    trace = []

    manager.register(:first) do |context|
      trace << :first
      context[:count] = 1
    end

    manager.register(:second) do |context|
      trace << :second
      context[:count] += 1
    end

    context = manager.run({})

    assert_equal [:first, :second], trace
    assert_equal 2, context[:count]
  end

  def test_accepts_callable_objects
    manager = Aurora::PassManager.new
    accumulator = Class.new do
      attr_reader :calls
      def initialize
        @calls = 0
      end
      def call(context)
        @calls += 1
        context[:calls] = @calls
      end
    end.new

    manager.register(:callable, accumulator)
    context = manager.run({})

    assert_equal 1, accumulator.calls
    assert_equal 1, context[:calls]
  end

  def test_bubbles_up_pass_errors_with_context
    manager = Aurora::PassManager.new
    manager.register(:boom) { |_ctx| raise RuntimeError, "failure" }

    error = assert_raises(RuntimeError) { manager.run({}) }
    assert_match(/Pass boom failed: failure/, error.message)
  end
end

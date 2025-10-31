# frozen_string_literal: true

require_relative "../test_helper"

class ApplicationTest < Minitest::Test
  def test_builds_services
    app = Aurora::Application.new

    to_core = app.build_to_core
    assert_instance_of Aurora::IRGen, to_core

    lowering = app.build_cpp_lowering(type_registry: Aurora::TypeRegistry.new)
    assert_instance_of Aurora::Backend::CppLowering, lowering
    assert_same app.event_bus, lowering.event_bus
  end

  def test_accepts_custom_subscribers
    events = []
    custom_logger = ->(bus) { bus.subscribe(:custom) { |payload| events << payload } }
    app = Aurora::Application.new(logger: nil, subscribers: [custom_logger])

    app.event_bus.publish(:custom, foo: 1)

    assert_equal [{foo: 1}], events
  end

  def test_configure_rules_allows_custom_registration
    configure_called = false
    custom_rule = Class.new(Aurora::Rules::BaseRule) do
      def applies?(_node, _context = {}) = false
    end

    app = Aurora::Application.new(logger: nil, configure_rules: lambda do |engine|
      configure_called = true
      engine.register(:custom_stage, custom_rule.new)
    end)

    assert configure_called
    assert app.rule_engine.registry.key?(:custom_stage)
  end
end

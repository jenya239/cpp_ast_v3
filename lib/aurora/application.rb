# frozen_string_literal: true

require_relative "event_bus"
require_relative "rules/rule_engine"
require_relative "diagnostics/event_logger"
require_relative "passes/to_core"
require_relative "backend/cpp_lowering"
require_relative "stdlib_scanner"

module Aurora
  class Application
    attr_reader :event_bus, :rule_engine

    def initialize(event_bus: nil, rule_engine: nil, logger: Diagnostics::EventLogger, subscribers: [], configure_rules: nil)
      @event_bus = event_bus || EventBus.new
      logger.attach(@event_bus) if logger
      Array(subscribers).each { |subscriber| subscriber.call(@event_bus) }
      @rule_engine = rule_engine || build_default_rule_engine
      configure_rules&.call(@rule_engine)
    end

    def build_to_core
      Passes::ToCore.new(rule_engine: @rule_engine, event_bus: @event_bus)
    end

    def build_cpp_lowering(type_registry:, function_registry: nil, stdlib_scanner: StdlibScanner.new)
      Backend::CppLowering.new(
        type_registry: type_registry,
        function_registry: function_registry,
        stdlib_scanner: stdlib_scanner,
        rule_engine: @rule_engine,
        event_bus: @event_bus
      )
    end

    private

    def build_default_rule_engine
      Aurora::Rules::RuleEngine.new
    end
  end
end

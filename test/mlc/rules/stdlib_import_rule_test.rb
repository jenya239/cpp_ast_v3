# frozen_string_literal: true

require_relative "../../test_helper"

class StdlibImportRuleTest < Minitest::Test
  def setup
    @registry = MLC::StdlibSignatureRegistry.new
    @rule = MLC::Rules::IRGen::StdlibImportRule.new
  end

  def test_registers_selected_functions
    import = MLC::AST::ImportDecl.new(path: "IO", items: ["println"])
    functions = []
    events = []

    @rule.apply(import, {
      stdlib_registry: @registry,
      register_stdlib_function: ->(metadata, _module_info, _alias_name) { functions << metadata.name },
      event_bus: build_event_bus(events)
    })

    assert_includes functions, "println"
    assert_equal :stdlib_function_imported, events.first[:event]
  end

  def test_logs_missing_items
    import = MLC::AST::ImportDecl.new(path: "IO", items: ["NO_SUCH"])
    missing = []

    events = []

    @rule.apply(import, {
      stdlib_registry: @registry,
      on_missing_item: ->(name, import_origin) { missing << [name, import_origin] },
      event_bus: build_event_bus(events)
    })

    assert_equal "NO_SUCH", missing.first.first
    assert_nil missing.first.last
    assert_equal :stdlib_missing_item, events.first[:event]
  end

  def test_handles_import_all
    import = MLC::AST::ImportDecl.new(path: "Graphics", import_all: true)
    functions = []
    types = []
    events = []

    @rule.apply(import, {
      stdlib_registry: @registry,
      register_stdlib_function: ->(metadata, _module_info, _alias_name) { functions << metadata.name },
      register_stdlib_type: ->(decl, _ns, _module_name) { types << decl.name },
      event_bus: build_event_bus(events)
    })

    refute_empty functions
    refute_empty types
    assert events.any? { |event| event[:event] == :stdlib_function_imported }
    assert events.any? { |event| event[:event] == :stdlib_type_imported }
  end

  private

  def build_event_bus(events)
    MLC::EventBus.new.tap do |bus|
      bus.subscribe(:stdlib_function_imported) do |payload|
        events << {event: :stdlib_function_imported, payload: payload}
      end
      bus.subscribe(:stdlib_missing_item) do |payload|
        events << {event: :stdlib_missing_item, payload: payload}
      end
      bus.subscribe(:stdlib_type_imported) do |payload|
        events << {event: :stdlib_type_imported, payload: payload}
      end
    end
  end
end

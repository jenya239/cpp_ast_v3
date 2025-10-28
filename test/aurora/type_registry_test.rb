# frozen_string_literal: true

require_relative "../test_helper"

class TypeRegistryTest < Minitest::Test
  def setup
    @registry = Aurora::TypeRegistry.new
  end

  def test_types_in_module_returns_registered_types
    register_record("Widget", module_name: "UI::Widgets", exported: true)

    module_types = @registry.types_in_module("UI::Widgets")
    assert_equal ["Widget"], module_types.map(&:name)
  end

  def test_types_in_module_can_filter_exported_only
    register_record("Widget", module_name: "UI::Widgets", exported: true)
    register_record("InternalWidget", module_name: "UI::Widgets", exported: false)

    all_types = @registry.types_in_module("UI::Widgets")
    assert_equal %w[InternalWidget Widget], all_types.map(&:name).sort

    exported_types = @registry.types_in_module("UI::Widgets", exported_only: true)
    assert_equal ["Widget"], exported_types.map(&:name)
    assert_equal exported_types, @registry.exported_types_in_module("UI::Widgets")
  end

  def test_re_registering_moves_type_between_modules
    register_record("Widget", module_name: "UI::Widgets", exported: true)
    register_record("Widget", module_name: "UI::Components", exported: true)

    assert_empty @registry.types_in_module("UI::Widgets")
    assert_equal ["Widget"], @registry.types_in_module("UI::Components").map(&:name)
  end

  private

  def register_record(name, module_name:, exported:)
    record = Aurora::CoreIR::RecordType.new(name: name, fields: [])
    @registry.register(
      name,
      core_ir_type: record,
      kind: :record,
      exported: exported,
      module_name: module_name
    )
  end
end

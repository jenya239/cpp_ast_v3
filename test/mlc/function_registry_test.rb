# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mlc/function_registry"

module MLC
  class FunctionRegistryTest < Minitest::Test
    TestFunctionInfo = Struct.new(:name, :param_types, :ret_type, :type_params)

    def setup
      super
      @registry = FunctionRegistry.new
    end

    def test_register_and_fetch_basic_info
      info = TestFunctionInfo.new("foo", [:i32], :i32, [])
      @registry.register("foo", info)

      assert @registry.registered?("foo")
      assert_equal info, @registry.fetch("foo")
      assert_nil @registry.fetch("missing")
      assert_equal ["foo"], @registry.names
    end

    def test_register_with_metadata_and_update
      info = TestFunctionInfo.new("bar", [], :void, [])
      @registry.register(
        "bar",
        info,
        namespace: "mlc::math",
        module_name: "Math",
        exported: true,
        external: true,
        effects: [:noexcept]
      )

      entry = @registry.fetch_entry("bar")
      assert_equal "mlc::math", entry.namespace
      assert_equal "Math", entry.module_name
      assert entry.exported?
      assert entry.external?
      assert_equal [:noexcept], entry.effects
      assert_equal "mlc::math::bar", entry.qualified_name

      @registry.update("bar", namespace: "mlc::core", exported: false, append_effects: [:constexpr])
      entry = @registry.fetch_entry("bar")
      assert_equal "mlc::core", entry.namespace
      refute entry.exported?
      assert_includes entry.effects, :constexpr
      assert_equal [:noexcept, :constexpr].sort, entry.effects.sort
    end

    def test_alias_registration_and_lookup
      info = TestFunctionInfo.new("baz", [], :i32, [])
      @registry.register("baz", info)
      @registry.register_alias("baz_alias", "baz")

      assert @registry.registered?("baz_alias")
      assert_equal info, @registry.fetch("baz_alias")
      entry = @registry.fetch_entry("baz_alias")
      assert_equal ["baz_alias"], entry.aliases
      assert_equal "baz", @registry.canonical_name("baz_alias")
    end

    def test_alias_registration_via_metadata
      info = TestFunctionInfo.new("sum", [], :i32, [])
      @registry.register("sum", info, aliases: ["s"])

      assert_equal info, @registry.fetch("s")
      assert_equal ["s"], @registry.aliases_for("sum")
    end

    def test_fetch_member_helper
      info = TestFunctionInfo.new("mul", [], :i32, [])
      @registry.register("mul", info, aliases: ["Math.mul"])

      assert_equal info, @registry.fetch_member("Math", "mul")
      assert_equal info, @registry.fetch("Math.mul")
    end

    def test_delete_alias_and_function
      info = TestFunctionInfo.new("qux", [], :void, [])
      @registry.register("qux", info, aliases: ["alias_qux"])
      assert_equal info, @registry.fetch("alias_qux")

      @registry.delete("alias_qux")
      refute @registry.registered?("alias_qux")
      assert @registry.registered?("qux")

      @registry.delete("qux")
      refute @registry.registered?("qux")
      assert @registry.empty?
    end

    def test_namespace_and_module_queries
      info_a = TestFunctionInfo.new("fn_a", [], :void, [])
      info_b = TestFunctionInfo.new("fn_b", [], :void, [])
      info_c = TestFunctionInfo.new("fn_c", [], :void, [])

      @registry.register("fn_a", info_a, namespace: "mlc::math", module_name: "Math")
      @registry.register("fn_b", info_b, namespace: "mlc::math", module_name: "Math")
      @registry.register("fn_c", info_c, namespace: "mlc::io", module_name: "IO")

      math_entries = @registry.functions_in_namespace("mlc::math")
      assert_equal 2, math_entries.size
      assert_equal %w[fn_a fn_b].sort, math_entries.map(&:name).sort

      module_entries = @registry.functions_in_module("Math")
      assert_equal 2, module_entries.size
      assert_equal %w[fn_a fn_b].sort, module_entries.map(&:name).sort
    end

    def test_exported_and_external_queries
      info = TestFunctionInfo.new("ext", [], :void, [])
      @registry.register("ext", info, exported: true, external: true)

      exported_names = @registry.exported_functions.map(&:name)
      external_names = @registry.external_functions.map(&:name)

      assert_equal ["ext"], exported_names
      assert_equal ["ext"], external_names
    end

    def test_clear_resets_registry
      info = TestFunctionInfo.new("clear_me", [], :void, [])
      @registry.register("clear_me", info, aliases: ["c"])

      refute @registry.empty?
      @registry.clear
      assert @registry.empty?
      refute @registry.registered?("c")
    end
  end
end

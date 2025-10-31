# frozen_string_literal: true

require "test_helper"

module Aurora
  class FunctionRegistryIntegrationTest < Minitest::Test
    def test_registers_user_function_metadata
      source = <<~AURORA
        module Math::Vector

        export fn add(a: i32, b: i32) -> i32 = a + b
      AURORA

      transformer = IRGen.new
      ast = Aurora.parse(source)
      transformer.transform(ast)

      entry = transformer.function_registry.fetch_entry("add")
      refute_nil entry
      assert_equal "Math::Vector", entry.module_name
      assert_equal "math::vector", entry.namespace
      assert entry.exported?
      refute entry.external?
      assert_equal [:constexpr, :noexcept], entry.effects
    end

    def test_registers_stdlib_function_metadata
      source = <<~AURORA
        import Math::{hypotenuse}

        fn length(a: f32, b: f32) -> f32 =
          hypotenuse(a, b)
      AURORA

      transformer = IRGen.new
      ast = Aurora.parse(source)
      transformer.transform(ast)

      entry = transformer.function_registry.fetch_entry("hypotenuse")
      refute_nil entry
      assert_equal "Math", entry.module_name
      assert_equal "aurora::math", entry.namespace
      assert entry.exported?
      refute entry.external?
    end

    def test_wildcard_stdlib_alias_generates_function_lookup
      source = <<~AURORA
        import * as Math from "Math"

        fn calc(a: f32, b: f32) -> f32 =
          Math.hypotenuse(a, b)
      AURORA

      transformer = IRGen.new
      ast = Aurora.parse(source)
      core = transformer.transform(ast)

      calc_func = core.items.find { |item| item.is_a?(Aurora::CoreIR::Func) && item.name == "calc" }
      refute_nil calc_func
      call = calc_func.body

      assert_instance_of Aurora::CoreIR::CallExpr, call
      assert_instance_of Aurora::CoreIR::VarExpr, call.callee
      assert_equal "hypotenuse", call.callee.name

      alias_entry = transformer.function_registry.fetch_entry_for_member("Math", "hypotenuse")
      refute_nil alias_entry
      assert_equal "hypotenuse", alias_entry.name
    end

    def test_wildcard_user_module_alias_resolves_member
      module_source = <<~AURORA
        module MyMath

        export fn add(a: i32, b: i32) -> i32 = a + b
      AURORA

      transformer = IRGen.new
      transformer.transform(Aurora.parse(module_source))

      use_source = <<~AURORA
        module Demo

        import * as Math from MyMath

        fn sum(a: i32, b: i32) -> i32 = Math.add(a, b)
      AURORA

      core = transformer.transform(Aurora.parse(use_source))
      sum_func = core.items.find { |item| item.is_a?(Aurora::CoreIR::Func) && item.name == "sum" }
      refute_nil sum_func

      call = sum_func.body
      assert_instance_of Aurora::CoreIR::CallExpr, call
      assert_instance_of Aurora::CoreIR::VarExpr, call.callee
      assert_equal "add", call.callee.name

      alias_entry = transformer.function_registry.fetch_entry_for_member("Math", "add")
      refute_nil alias_entry
      assert_equal "add", alias_entry.name
    end

    def test_selective_user_module_import_registers_direct_alias
      module_source = <<~AURORA
        module Geometry

        export fn area(a: f32, b: f32) -> f32 = a * b
        export fn perimeter(a: f32, b: f32) -> f32 = 2.0 * (a + b)
      AURORA

      transformer = IRGen.new
      transformer.transform(Aurora.parse(module_source))

      use_source = <<~AURORA
        module Demo

        import Geometry::{area}

        fn square_area(x: f32) -> f32 = area(x, x)
      AURORA

      core = transformer.transform(Aurora.parse(use_source))
      func = core.items.find { |item| item.is_a?(Aurora::CoreIR::Func) && item.name == "square_area" }
      refute_nil func
      call = func.body

      assert_instance_of Aurora::CoreIR::CallExpr, call
      assert_equal "area", call.callee.name

      assert transformer.function_registry.registered?("area"), "area should remain registered"
      refute_includes transformer.function_registry.aliases_for("perimeter"), "Geometry.perimeter"
      assert_nil transformer.function_registry.fetch_member("Geometry", "perimeter"), "Member alias for non-imported function should be absent"
    end

    def test_selective_user_module_import_lowering_uses_namespace
      geometry_source = <<~AURORA
        module Geometry

        export fn area(a: f32, b: f32) -> f32 = a * b
        export fn perimeter(a: f32, b: f32) -> f32 = 2.0 * (a + b)
      AURORA

      demo_source = <<~AURORA
        module Demo

        import Geometry::{area}

        fn compute(a: f32, b: f32) -> f32 =
          area(a, b)
      AURORA

      transformer = IRGen.new
      transformer.transform(Aurora.parse(geometry_source))
      core = transformer.transform(Aurora.parse(demo_source))

      lowerer = Backend::CodeGen.new(
        type_registry: transformer.type_registry,
        function_registry: transformer.function_registry
      )

      cpp_program = lowerer.lower(core)
      cpp_source = cpp_program.to_source

      assert_includes cpp_source, "geometry::area"
      refute_includes cpp_source, "geometry::perimeter"

      header_generator = Backend::HeaderGenerator.new(lowerer)
      header_result = header_generator.generate(core)
      header = header_result[:header]

      assert_includes header, '#include "geometry.hpp"'
    end
  end
end

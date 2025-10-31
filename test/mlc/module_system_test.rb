# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"

class AuroraModuleSystemTest < Minitest::Test
  def test_parse_module_declaration
    aurora_source = <<~AURORA
      module Math

      fn add(a: i32, b: i32) -> i32 = a + b
    AURORA

    ast = MLC.parse(aurora_source)

    refute_nil ast.module_decl
    assert_equal "Math", ast.module_decl.name
    assert_equal 1, ast.declarations.length
  end

  def test_parse_nested_module_path
    aurora_source = <<~AURORA
      module Math::Vector

      fn dot(a: i32, b: i32) -> i32 = a + b
    AURORA

    ast = MLC.parse(aurora_source)

    assert_equal "Math::Vector", ast.module_decl.name
  end

  def test_parse_simple_import
    aurora_source = <<~AURORA
      import Math

      fn test() -> i32 = add(1, 2)
    AURORA

    ast = MLC.parse(aurora_source)

    assert_equal 1, ast.imports.length
    assert_equal "Math", ast.imports[0].path
    assert_nil ast.imports[0].items
  end

  def test_parse_nested_import_path
    aurora_source = <<~AURORA
      import Math::Vector

      fn test() -> i32 = dot(1, 2)
    AURORA

    ast = MLC.parse(aurora_source)

    assert_equal "Math::Vector", ast.imports[0].path
  end

  def test_parse_selective_import
    aurora_source = <<~AURORA
      import Math::{add, subtract}

      fn test() -> i32 = add(1, 2)
    AURORA

    ast = MLC.parse(aurora_source)

    assert_equal 1, ast.imports.length
    assert_equal "Math", ast.imports[0].path
    assert_equal ["add", "subtract"], ast.imports[0].items
  end

  def test_parse_multiple_imports
    aurora_source = <<~AURORA
      import Math
      import Vector

      fn test() -> i32 = 0
    AURORA

    ast = MLC.parse(aurora_source)

    assert_equal 2, ast.imports.length
    assert_equal "Math", ast.imports[0].path
    assert_equal "Vector", ast.imports[1].path
  end

  def test_transform_module_to_core_ir
    aurora_source = <<~AURORA
      module Math

      fn add(a: i32, b: i32) -> i32 = a + b
    AURORA

    ast = MLC.parse(aurora_source)
    core_ir = MLC.transform_to_core(ast)

    assert_equal "Math", core_ir.name
    assert_equal 1, core_ir.items.length
  end

  def test_transform_imports_to_core_ir
    aurora_source = <<~AURORA
      import Math

      fn test() -> i32 = 0
    AURORA

    ast = MLC.parse(aurora_source)
    core_ir = MLC.transform_to_core(ast)

    assert_equal 1, core_ir.imports.length
    assert_equal "Math", core_ir.imports[0].path
  end

  def test_generate_header_guard
    aurora_source = <<~AURORA
      module Math::Vector

      fn length(x: f32, y: f32) -> f32 = x + y
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    assert_includes result[:header], "#ifndef MATH_VECTOR_HPP"
    assert_includes result[:header], "#define MATH_VECTOR_HPP"
    assert_includes result[:header], "#endif // MATH_VECTOR_HPP"
  end

  def test_generate_namespace
    aurora_source = <<~AURORA
      module Math

      fn add(a: i32, b: i32) -> i32 = a + b
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    assert_includes result[:header], "namespace math {"
    assert_includes result[:header], "} // namespace math"
  end

  def test_generate_nested_namespace
    aurora_source = <<~AURORA
      module Math::Vector

      fn dot(a: i32, b: i32) -> i32 = a + b
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    assert_includes result[:header], "namespace math::vector {"
    assert_includes result[:header], "} // namespace math::vector"
  end

  def test_generate_include_from_import
    aurora_source = <<~AURORA
      import Math

      fn test() -> i32 = 0
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    assert_includes result[:header], '#include "math.hpp"'
  end

  def test_generate_nested_include_from_import
    aurora_source = <<~AURORA
      import Math::Vector

      fn test() -> i32 = 0
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    assert_includes result[:header], '#include "math/vector.hpp"'
  end

  def test_function_declaration_in_header
    aurora_source = <<~AURORA
      module Math

      fn add(a: i32, b: i32) -> i32 = a + b
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    # Header should have function declaration
    assert_includes result[:header], "int add(int a, int b);"

    # Implementation should have full function definition
    assert_includes result[:implementation], "int add(int a, int b)"
    assert_includes result[:implementation], "return"
  end

  def test_implementation_includes_own_header
    aurora_source = <<~AURORA
      module Math

      fn add(a: i32, b: i32) -> i32 = a + b
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    # Implementation should include its own header
    assert_includes result[:implementation], '#include "math.hpp"'
  end

  def test_parse_module_with_slash_path
    aurora_source = <<~AURORA
      module app/geom

      fn area(r: i32) -> i32 = r * r
    AURORA

    ast = MLC.parse(aurora_source)
    assert_equal "app/geom", ast.module_decl.name

    result = MLC.to_hpp_cpp(aurora_source)
    assert_includes result[:header], 'namespace app::geom {'
    assert_includes result[:implementation], '#include "app/geom.hpp"'
  end

  def test_import_with_slash_path
    aurora_source = <<~AURORA
      import std/containers

      fn test() -> i32 = 0
    AURORA

    ast = MLC.parse(aurora_source)
    assert_equal "std/containers", ast.imports.first.path

    result = MLC.to_hpp_cpp(aurora_source)
    assert_includes result[:implementation], '#include "std/containers.hpp"'
  end

  def test_type_declaration_in_header
    aurora_source = <<~AURORA
      module Shapes

      type Shape = Circle(f32) | Rect(f32, f32)
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    # Type declarations should be in header
    assert_includes result[:header], "struct Circle"
    assert_includes result[:header], "struct Rect"
  end

  def test_generic_function_in_header
    aurora_source = <<~AURORA
      module Utils

      fn identity<T>(x: T) -> T = x
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    # Generic function declaration should have template
    assert_includes result[:header], "template<typename T>"
    assert_includes result[:header], "T identity(T x);"
  end

  def test_complete_module_example
    aurora_source = <<~AURORA
      module Math::Geometry

      import Math::Vector

      type Shape = Circle(f32) | Rect(f32, f32)

      fn area(s: Shape) -> f32 =
        match s
          | Circle(r) => r * r
          | Rect(w, h) => w * h
    AURORA

    result = MLC.to_hpp_cpp(aurora_source)

    # Verify header structure
    assert_includes result[:header], "#ifndef MATH_GEOMETRY_HPP"
    assert_includes result[:header], "namespace math::geometry {"
    assert_includes result[:header], '#include "math/vector.hpp"'
    assert_includes result[:header], "struct Circle"
    assert_includes result[:header], "float area"

    # Verify implementation
    assert_includes result[:implementation], '#include "math/geometry.hpp"'
    assert_includes result[:implementation], "namespace math::geometry {"
    assert_includes result[:implementation], "float area"
  end
end

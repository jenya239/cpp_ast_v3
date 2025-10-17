# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraSumTypesTest < Minitest::Test
  def test_simple_sum_type
    aurora_source = <<~AURORA
      type Shape = Circle(f32) | Rect(f32, f32) | Point
    AURORA

    # Parse should work
    ast = Aurora.parse(aurora_source)
    refute_nil ast

    # Should have type declaration
    assert_equal 1, ast.declarations.length
    type_decl = ast.declarations.first
    assert_instance_of Aurora::AST::TypeDecl, type_decl
    assert_equal "Shape", type_decl.name

    # Type should be SumType
    assert_instance_of Aurora::AST::SumType, type_decl.type
    sum_type = type_decl.type

    # Should have 3 variants
    assert_equal 3, sum_type.variants.length

    # Check Circle variant
    circle = sum_type.variants[0]
    assert_equal "Circle", circle[:name]
    assert_equal 1, circle[:fields].length
    assert_equal "f32", circle[:fields][0][:type].name

    # Check Rect variant
    rect = sum_type.variants[1]
    assert_equal "Rect", rect[:name]
    assert_equal 2, rect[:fields].length

    # Check Point variant (no fields)
    point = sum_type.variants[2]
    assert_equal "Point", point[:name]
    assert_equal 0, point[:fields].length
  end

  def test_sum_type_with_named_fields
    aurora_source = <<~AURORA
      type Result = Ok { value: i32 } | Err { message: i32 }
    AURORA

    ast = Aurora.parse(aurora_source)
    type_decl = ast.declarations.first
    sum_type = type_decl.type

    assert_equal 2, sum_type.variants.length

    ok_variant = sum_type.variants[0]
    assert_equal "Ok", ok_variant[:name]
    assert_equal 1, ok_variant[:fields].length
    assert_equal "value", ok_variant[:fields][0][:name]

    err_variant = sum_type.variants[1]
    assert_equal "Err", err_variant[:name]
    assert_equal "message", err_variant[:fields][0][:name]
  end

  def test_sum_type_lowering_to_cpp

    aurora_source = <<~AURORA
      type Shape = Circle(f32) | Rect(f32, f32) | Point
    AURORA

    cpp_code = Aurora.to_cpp(aurora_source)

    # Should generate structs for each variant
    assert_includes cpp_code, "struct Circle"
    assert_includes cpp_code, "struct Rect"
    assert_includes cpp_code, "struct Point"

    # Should generate variant type
    assert_includes cpp_code, "std::variant"
    assert_includes cpp_code, "using Shape ="
  end
end

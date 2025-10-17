# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraPatternMatchingTest < Minitest::Test
  def test_parse_simple_match
    aurora_source = <<~AURORA
      fn test(x: i32) -> i32 =
        match x
          | 0 => 1
          | 1 => 2
          | _ => 3
    AURORA

    ast = Aurora.parse(aurora_source)
    refute_nil ast

    func = ast.declarations.first
    assert_instance_of Aurora::AST::FuncDecl, func

    # Body should be MatchExpr
    assert_instance_of Aurora::AST::MatchExpr, func.body
    match_expr = func.body

    # Should have 3 arms
    assert_equal 3, match_expr.arms.length

    # Check first arm (literal pattern)
    arm1 = match_expr.arms[0]
    assert_equal :literal, arm1[:pattern].kind

    # Check third arm (wildcard pattern)
    arm3 = match_expr.arms[2]
    assert_equal :wildcard, arm3[:pattern].kind
  end

  def test_parse_constructor_pattern
    aurora_source = <<~AURORA
      type Shape = Circle(f32) | Point

      fn area(s: Shape) -> f32 =
        match s
          | Circle(r) => r
          | Point => 0.0
    AURORA

    ast = Aurora.parse(aurora_source)
    assert_equal 2, ast.declarations.length

    func = ast.declarations[1]
    match_expr = func.body

    assert_instance_of Aurora::AST::MatchExpr, match_expr
    assert_equal 2, match_expr.arms.length

    # First arm should be constructor pattern
    arm1 = match_expr.arms[0]
    assert_equal :constructor, arm1[:pattern].kind
    assert_equal "Circle", arm1[:pattern].data[:name]
    assert_equal 1, arm1[:pattern].data[:fields].length
  end

  def test_match_lowering_to_cpp
    aurora_source = <<~AURORA
      type Shape = Circle(f32) | Point

      fn area(s: Shape) -> f32 =
        match s
          | Circle(r) => r
          | Point => 0.0
    AURORA

    cpp_code = Aurora.to_cpp(aurora_source)

    # Should generate std::visit with lambda overload
    assert_includes cpp_code, "std::visit"
    assert_includes cpp_code, "overloaded"
    assert_includes cpp_code, "Circle"
    assert_includes cpp_code, "Point"
  end

  def test_match_with_multiple_fields
    aurora_source = <<~AURORA
      type Shape = Rect(f32, f32) | Point

      fn area(s: Shape) -> f32 =
        match s
          | Rect(w, h) => w
          | Point => 0.0
    AURORA

    ast = Aurora.parse(aurora_source)
    func = ast.declarations[1]
    match_expr = func.body

    arm1 = match_expr.arms[0]
    assert_equal :constructor, arm1[:pattern].kind
    assert_equal 2, arm1[:pattern].data[:fields].length
    assert_equal "w", arm1[:pattern].data[:fields][0]
    assert_equal "h", arm1[:pattern].data[:fields][1]
  end
end

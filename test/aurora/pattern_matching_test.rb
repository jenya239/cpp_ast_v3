# frozen_string_literal: true

require "tmpdir"
require "fileutils"
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
    assert_instance_of Aurora::AST::BlockExpr, arm1[:body]
    assert_empty arm1[:body].statements
    refute_nil arm1[:body].result_expr

    # Check third arm (wildcard pattern)
    arm3 = match_expr.arms[2]
    assert_equal :wildcard, arm3[:pattern].kind
    assert_instance_of Aurora::AST::BlockExpr, arm3[:body]
    assert_empty arm3[:body].statements
    refute_nil arm3[:body].result_expr
  end

  def test_parse_constructor_pattern
    aurora_source = <<~AURORA
      type Shape = Circle(f32) | Point

      fn area(s: Shape) -> f32 =
        match s
          | Circle(r) => r
          | Point => 0.0f
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
    assert_instance_of Aurora::AST::BlockExpr, arm1[:body]
  end

  def test_match_lowering_to_cpp
    aurora_source = <<~AURORA
      type Result = Ok(i32) | Err

      fn unwrap(res: Result) -> i32 =
        match res
          | Ok(value) => value
          | Err => 0
    AURORA

    cpp_code = Aurora.to_cpp(aurora_source)

    # Should generate std::visit with lambda overload and helper include
    assert_includes cpp_code, '#include "aurora_match.hpp"'
    assert_includes cpp_code, "std::visit"
    assert_includes cpp_code, "overloaded"
    assert_includes cpp_code, "Ok"
    assert_includes cpp_code, "Err"

    program = <<~CPP
      #include <variant>
      #include <string>
      #include <utility>
      #{cpp_code}

      int main() {
        Result res = Ok{42};
        int value = unwrap(res);
        return (value == 42) ? 0 : 1;
      }
    CPP

    assert_cpp_compiles_and_runs(program)
  end

  def test_match_with_multiple_fields
    aurora_source = <<~AURORA
      type Shape = Rect(f32, f32) | Point

      fn area(s: Shape) -> f32 =
        match s
          | Rect(w, h) => w
          | Point => 0.0f
    AURORA

    ast = Aurora.parse(aurora_source)
    func = ast.declarations[1]
    match_expr = func.body

    arm1 = match_expr.arms[0]
    assert_equal :constructor, arm1[:pattern].kind
    assert_equal 2, arm1[:pattern].data[:fields].length
    assert_equal "w", arm1[:pattern].data[:fields][0]
    assert_equal "h", arm1[:pattern].data[:fields][1]
    assert_instance_of Aurora::AST::BlockExpr, arm1[:body]
  end

  def test_match_statement_lowering_is_void_visit
    aurora_source = <<~AURORA
      type Result = Ok(i32) | Err

      fn handle(res: Result) -> void =
        match res
          | Ok(value) => do
            let temp = value;
          end
          | Err => do
          end
    AURORA

    cpp_code = Aurora.to_cpp(aurora_source)

    assert_includes cpp_code, "std::visit(overloaded"
    refute_includes cpp_code, "[&]()"
    assert_includes cpp_code, "auto [value] = ok;"
  end
end

private

def assert_cpp_compiles_and_runs(cpp_code)
  runtime_dir = File.expand_path("../../runtime", __dir__)
  Dir.mktmpdir("aurora_pattern") do |dir|
    source_path = File.join(dir, "pattern_test.cpp")
    binary_path = File.join(dir, "pattern_test")

    File.write(source_path, cpp_code)

    compile_cmd = [
      "g++",
      "-std=c++20",
      "-I", runtime_dir,
      source_path,
      "-o", binary_path
    ]
    assert system(*compile_cmd), "Compilation failed for:\n#{cpp_code}"
    assert system(binary_path), "Program execution failed for:\n#{cpp_code}"
  end
end

# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraLambdaTest < Minitest::Test
  def test_parse_simple_lambda
    aurora_source = <<~AURORA
      fn test() -> i32 =
        let f = x => x + 1;
        f(5)
    AURORA

    ast = Aurora.parse(aurora_source)
    func = ast.declarations.first

    # Body should be a block with variable declaration and usage
    assert_instance_of Aurora::AST::Block, func.body
    assert_equal 2, func.body.stmts.size
    assert_instance_of Aurora::AST::VariableDecl, func.body.stmts.first

    # Value should be a lambda
    lambda_expr = func.body.stmts.first.value
    assert_instance_of Aurora::AST::Lambda, lambda_expr
    assert_equal 1, lambda_expr.params.length
    assert_instance_of Aurora::AST::LambdaParam, lambda_expr.params[0]
    assert_equal "x", lambda_expr.params[0].name
  end

  def test_parse_lambda_with_multiple_params
    aurora_source = <<~AURORA
      fn test() -> i32 =
        let add = (x, y) => x + y;
        add(2, 3)
    AURORA

    ast = Aurora.parse(aurora_source)
    func = ast.declarations.first
    block = func.body
    assert_instance_of Aurora::AST::Block, block
    lambda_expr = block.stmts.first.value

    assert_instance_of Aurora::AST::Lambda, lambda_expr
    assert_equal 2, lambda_expr.params.length
    assert_equal ["x", "y"], lambda_expr.params.map(&:name)
  end

  def test_parse_lambda_with_types
    aurora_source = <<~AURORA
      fn test() -> i32 =
        let f = (x: i32) => x + 1;
        f(5)
    AURORA

    ast = Aurora.parse(aurora_source)
    func = ast.declarations.first
    block = func.body
    lambda_expr = block.stmts.first.value

    assert_equal "i32", lambda_expr.params[0].type.name
  end

  def test_lambda_lowering_to_cpp
    # Test direct lambda expression (not in let binding)
    aurora_source = <<~AURORA
      fn apply() -> i32 =
        (x => x + 1)(5)
    AURORA

    cpp_code = Aurora.to_cpp(aurora_source)

    # Should generate C++ lambda
    assert_includes cpp_code, "[]"
    assert_includes cpp_code, "return"
    assert_includes cpp_code, "int x"
  end

  def test_lambda_in_function_call
    aurora_source = <<~AURORA
      fn apply(x: i32) -> i32 =
        let f = y => y + 1;
        f(x)
    AURORA

    ast = Aurora.parse(aurora_source)
    refute_nil ast
  end
end

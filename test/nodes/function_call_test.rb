# frozen_string_literal: true

require_relative "../test_helper"

class TestFunctionCall < Minitest::Test
  def test_simple_no_args
    callee = CppAst::Nodes::Identifier.new(name: "foo")
    node = CppAst::Nodes::FunctionCallExpression.new(
      callee: callee,
      arguments: []
    )
    
    assert_equal "foo()", node.to_source
  end
  
  def test_one_argument
    callee = CppAst::Nodes::Identifier.new(name: "foo")
    arg = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::FunctionCallExpression.new(
      callee: callee,
      arguments: [arg]
    )
    
    assert_equal "foo(x)", node.to_source
  end
  
  def test_multiple_arguments
    callee = CppAst::Nodes::Identifier.new(name: "add")
    arg1 = CppAst::Nodes::Identifier.new(name: "x")
    arg2 = CppAst::Nodes::Identifier.new(name: "y")
    node = CppAst::Nodes::FunctionCallExpression.new(
      callee: callee,
      arguments: [arg1, arg2]
    )
    
    assert_equal "add(x,y)", node.to_source
  end
  
  def test_with_argument_separators
    callee = CppAst::Nodes::Identifier.new(name: "add")
    arg1 = CppAst::Nodes::Identifier.new(name: "x")
    arg2 = CppAst::Nodes::Identifier.new(name: "y")
    node = CppAst::Nodes::FunctionCallExpression.new(
      callee: callee,
      arguments: [arg1, arg2],
      argument_separators: [", "]
    )
    
    assert_equal "add(x, y)", node.to_source
  end
  
  def test_with_spaces_after_paren
    callee = CppAst::Nodes::Identifier.new(name: "foo")
    arg = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::FunctionCallExpression.new(
      callee: callee,
      arguments: [arg],
      lparen_suffix: " ",
      rparen_prefix: " "
    )
    
    assert_equal "foo( x )", node.to_source
  end
  
  def test_three_arguments
    callee = CppAst::Nodes::Identifier.new(name: "func")
    arg1 = CppAst::Nodes::NumberLiteral.new(value: "1")
    arg2 = CppAst::Nodes::NumberLiteral.new(value: "2")
    arg3 = CppAst::Nodes::NumberLiteral.new(value: "3")
    node = CppAst::Nodes::FunctionCallExpression.new(
      callee: callee,
      arguments: [arg1, arg2, arg3],
      argument_separators: [", ", ", "]
    )
    
    assert_equal "func(1, 2, 3)", node.to_source
  end
  
  def test_nested_call
    inner_callee = CppAst::Nodes::Identifier.new(name: "inner")
    inner_call = CppAst::Nodes::FunctionCallExpression.new(
      callee: inner_callee,
      arguments: []
    )
    
    outer_callee = CppAst::Nodes::Identifier.new(name: "outer")
    outer_call = CppAst::Nodes::FunctionCallExpression.new(
      callee: outer_callee,
      arguments: [inner_call]
    )
    
    assert_equal "outer(inner())", outer_call.to_source
  end
end

